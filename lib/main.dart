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
      title: 'Buy List Guard',
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

  Future<void> _removeItem(BuyItem item) async {
    setState(() {
      _items = _items.where((current) => current.id != item.id).toList();
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
      appBar: AppBar(title: const Text('Buy List')),
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
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Dismissible(
          key: ValueKey(item.id),
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
            _removeItem(item);
          },
          child: CheckboxListTile(
            value: item.needed,
            onChanged: (value) {
              if (value == null) return;
              _toggleNeeded(item, value);
            },
            title: Text(item.name, style: _titleStyle(context, item.needed)),
            controlAffinity: ListTileControlAffinity.leading,
            secondary: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove',
              onPressed: () {
                _removeItem(item);
              },
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 0),
    );
  }

  TextStyle? _titleStyle(BuildContext context, bool needed) {
    if (needed) {
      return Theme.of(context).textTheme.bodyLarge;
    }
    final base = Theme.of(context).textTheme.bodyLarge;
    return base?.copyWith(
          decoration: TextDecoration.lineThrough,
          color: base.color?.withOpacity(0.6),
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

  static const _storageKey = 'buylistguard.items';

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
