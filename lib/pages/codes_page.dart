import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../models/stored_code.dart';
import '../storage/code_storage.dart';
import '../widgets/buy_list_app_bar.dart';

class CodesPage extends StatefulWidget {
  const CodesPage({super.key, required this.storage});

  final CodeStorage storage;

  @override
  State<CodesPage> createState() => _CodesPageState();
}

class _CodesPageState extends State<CodesPage> {
  final ImagePicker _picker = ImagePicker();
  List<StoredCode> _codes = const [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCodes();
  }

  Future<void> _loadCodes() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final stored = await widget.storage.loadCodes();
      final existing = <StoredCode>[];
      for (final code in stored) {
        final file = File(code.imagePath);
        if (await file.exists()) {
          existing.add(code);
        } else {
          await widget.storage.deleteImageIfExists(code.imagePath);
        }
      }
      if (existing.length != stored.length) {
        await widget.storage.saveCodes(existing);
      }
      if (!mounted) return;
      setState(() {
        _codes = existing;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Could not load your codes. Please try again.';
      });
    }
  }

  Future<void> _addCode() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) {
        return;
      }

      final name = await _promptForName();
      if (name == null) {
        return;
      }
      final trimmedName = name.trim();
      if (trimmedName.isEmpty) {
        _showSnackBar('Name cannot be empty.');
        return;
      }

      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final extension = _extensionForPath(picked.path);
      final targetPath = await widget.storage.reserveImagePath(id, extension);
      await File(picked.path).copy(targetPath);

      final newCode = StoredCode(
        id: id,
        name: trimmedName,
        imagePath: targetPath,
        createdAt: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _codes = [newCode, ..._codes];
      });
      await widget.storage.saveCodes(_codes);
      _showSnackBar('Saved "$trimmedName"');
    } catch (error) {
      _showSnackBar('Could not add code. Please try again.');
    }
  }

  Future<void> _removeCode(
    StoredCode code, {
    int? index,
    bool showUndo = false,
  }) async {
    final removalIndex = index ?? _codes.indexWhere((c) => c.id == code.id);
    if (removalIndex < 0) {
      return;
    }

    setState(() {
      _codes = List<StoredCode>.from(_codes)..removeAt(removalIndex);
    });
    await widget.storage.saveCodes(_codes);

    Future<void> deleteImage() async {
      await widget.storage.deleteImageIfExists(code.imagePath);
    }

    if (!mounted) {
      await deleteImage();
      return;
    }

    if (!showUndo) {
      await deleteImage();
      _showSnackBar('Removed "${code.name}"');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text('Removed "${code.name}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted) {
              return;
            }
            setState(() {
              final updated = List<StoredCode>.from(_codes);
              final insertIndex = removalIndex > updated.length
                  ? updated.length
                  : removalIndex;
              updated.insert(insertIndex, code);
              _codes = updated;
            });
            unawaited(widget.storage.saveCodes(_codes));
          },
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    controller.closed.then((reason) async {
      if (reason != SnackBarClosedReason.action) {
        await deleteImage();
      }
    });
  }

  Future<String?> _promptForName() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name this code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Grocery Rewards'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _extensionForPath(String path) {
    final extension = p.extension(path);
    if (extension.isEmpty) {
      return 'png';
    }
    return extension.replaceFirst('.', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BuyListAppBar(),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCode,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Add code'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_codes.isEmpty) {
      return const _EmptyCodesState();
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96, left: 16, right: 16, top: 16),
      itemCount: _codes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final code = _codes[index];
        return Dismissible(
          key: ValueKey(code.id),
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
            _removeCode(code, index: index, showUndo: true);
          },
          child: ListTile(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CodeViewerPage(code: code),
                ),
              );
            },
            leading: AspectRatio(
              aspectRatio: 1,
              child: Hero(
                tag: code.id,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(code.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) => const ColoredBox(
                      color: Color(0xFFE0E0E0),
                      child: Icon(Icons.broken_image),
                    ),
                  ),
                ),
              ),
            ),
            title: Text(code.name),
            subtitle: Text(
              'Saved ${_formatTimestamp(code.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inDays >= 1) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }
    if (difference.inHours >= 1) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    }
    if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    }
    return 'Just now';
  }
}

class _EmptyCodesState extends StatelessWidget {
  const _EmptyCodesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.qr_code_scanner, size: 64, color: Colors.black54),
            SizedBox(height: 16),
            Text(
              'No codes yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Save screenshots of your store barcodes here so you can pull them up quickly at checkout.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class CodeViewerPage extends StatelessWidget {
  const CodeViewerPage({super.key, required this.code});

  final StoredCode code;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BuyListAppBar(),
      body: InteractiveViewer(
        panEnabled: true,
        minScale: 0.5,
        maxScale: 5,
        child: Center(
          child: Hero(
            tag: code.id,
            child: Image.file(
              File(code.imagePath),
              fit: BoxFit.contain,
              errorBuilder: (context, _, __) => Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.broken_image, size: 48, color: Colors.black45),
                  SizedBox(height: 12),
                  Text('Code image missing'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
