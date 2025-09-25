import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await BuyListStorage.create();
  runApp(BuyListApp(storage: storage));
}

class BuyListApp extends StatelessWidget {
  const BuyListApp({super.key, required this.storage});

  final BuyListStorage storage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Buy List Guardian',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: BuyListPage(storage: storage),
    );
  }
}

class BuyListPage extends StatefulWidget {
  const BuyListPage({super.key, required this.storage});

  final BuyListStorage storage;

  @override
  State<BuyListPage> createState() => _BuyListPageState();
}

class _BuyListPageState extends State<BuyListPage> {
  List<BuyItem> _items = const [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await widget.storage.loadItems();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _loading = false;
        _errorMessage = 'Could not load your list. Please try again.';
      });
    }
  }

  Future<void> _addItem(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _items = [..._items, BuyItem.newItem(name: trimmed)];
    });
    await widget.storage.saveItems(_items);
  }

  Future<void> _toggleNeeded(BuyItem item, bool needed) async {
    setState(() {
      _items = _items
          .map(
            (current) => current.id == item.id
                ? current.copyWith(needed: needed)
                : current,
          )
          .toList();
    });
    await widget.storage.saveItems(_items);
  }

  Future<void> _removeItem(
    BuyItem item, {
    int? index,
    bool showUndo = false,
  }) async {
    final removalIndex =
        index ?? _items.indexWhere((current) => current.id == item.id);
    if (removalIndex < 0) {
      return;
    }

    setState(() {
      _items = List<BuyItem>.from(_items)..removeAt(removalIndex);
    });

    await widget.storage.saveItems(_items);

    if (!showUndo || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed "${item.name}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (!mounted) {
                return;
              }
              setState(() {
                final restored = List<BuyItem>.from(_items);
                final insertIndex = removalIndex > restored.length
                    ? restored.length
                    : removalIndex;
                restored.insert(insertIndex, item);
                _items = restored;
              });
              unawaited(widget.storage.saveItems(_items));
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _reorderItems(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) {
      return;
    }

    final updated = List<BuyItem>.from(_items);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);

    setState(() {
      _items = updated;
    });

    await widget.storage.saveItems(_items);
  }

  Future<void> _showAddItemDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'What do you need to buy?',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != null) {
      await _addItem(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy List Guardian')),
      body: _buildBody(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddItemDialog();
        },
        tooltip: 'Add item',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, textAlign: TextAlign.center));
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'Your list is empty.\nTap + to add something to buy.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _items.length,
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        unawaited(_reorderItems(oldIndex, newIndex));
      },
      itemBuilder: (context, index) {
        final item = _items[index];
        final divider = index == _items.length - 1
            ? const BorderSide(width: 0, color: Colors.transparent)
            : Divider.createBorderSide(context, width: 0);

        return Dismissible(
          key: ValueKey('dismiss-${item.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          onDismissed: (_) {
            _removeItem(item, index: index, showUndo: true);
          },
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              key: ValueKey('item-${item.id}'),
              decoration: BoxDecoration(border: Border(bottom: divider)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: item.needed,
                    onChanged: (value) {
                      if (value == null) return;
                      _toggleNeeded(item, value);
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        _toggleNeeded(item, !item.needed);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          item.name,
                          style: _titleStyle(context, item.needed),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Semantics(
                    button: true,
                    label: 'Reorder ${item.name}',
                    child: ReorderableDragStartListener(
                      index: index,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                        child: Icon(
                          Icons.drag_indicator,
                          size: 26,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TextStyle? _titleStyle(BuildContext context, bool needed) {
    if (needed) {
      return Theme.of(context).textTheme.bodyLarge;
    }
    final base = Theme.of(context).textTheme.bodyLarge;
    return base?.copyWith(
          decoration: TextDecoration.lineThrough,
          color: base.color?.withValues(alpha: 0.6),
        ) ??
        const TextStyle(decoration: TextDecoration.lineThrough);
  }
}

class BuyItem {
  const BuyItem({required this.id, required this.name, required this.needed});

  factory BuyItem.newItem({required String name}) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    return BuyItem(id: id, name: name, needed: true);
  }

  factory BuyItem.fromJson(Map<String, dynamic> json) {
    return BuyItem(
      id: json['id'] as String,
      name: json['name'] as String,
      needed: json['needed'] as bool? ?? true,
    );
  }

  final String id;
  final String name;
  final bool needed;

  BuyItem copyWith({String? name, bool? needed}) {
    return BuyItem(
      id: id,
      name: name ?? this.name,
      needed: needed ?? this.needed,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'name': name, 'needed': needed};
  }
}

class BuyListStorage {
  BuyListStorage._(this._preferences);

  final SharedPreferences _preferences;

  static const _storageKey = 'buylistguardian.items';

  static Future<BuyListStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return BuyListStorage._(prefs);
  }

  Future<List<BuyItem>> loadItems() async {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map(
            (entry) =>
                BuyItem.fromJson(Map<String, dynamic>.from(entry as Map)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveItems(List<BuyItem> items) async {
    final encoded = jsonEncode(
      items.map((item) => item.toJson()).toList(growable: false),
    );
    await _preferences.setString(_storageKey, encoded);
  }
}
