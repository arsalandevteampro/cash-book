import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/transaction_service.dart';
import '../theme/app_theme.dart';

class ManageBooksScreen extends StatefulWidget {
  const ManageBooksScreen({super.key});

  @override
  State<ManageBooksScreen> createState() => _ManageBooksScreenState();
}

class _ManageBooksScreenState extends State<ManageBooksScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _collapsedBookIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleExpand(String bookId) {
    setState(() {
      if (_collapsedBookIds.contains(bookId)) {
        _collapsedBookIds.remove(bookId);
      } else {
        _collapsedBookIds.add(bookId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactionService = Provider.of<TransactionService>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final allBooks = transactionService.books;
    final currentBookId = transactionService.currentBookId;
    final rootBooks = transactionService.rootBooks;

    final filteredBooks = _searchQuery.isEmpty
        ? rootBooks
        : allBooks
            .where((b) => (b['name']?.toString() ?? '')
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Cash Books',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => _showCreateBookDialog(transactionService),
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primarySeedColor),
            tooltip: 'Add Main Book',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Overview Header Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFE6F4F1), const Color(0xFFCCECE6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primarySeedColor.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySeedColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_tree_rounded,
                        color: AppTheme.primarySeedColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Active Book',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            transactionService.currentBookName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primarySeedColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total ${allBooks.length} book(s) across ${rootBooks.length} root folder(s)',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search books by name...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                ),
              ),
            ),

            // Tree List view
            Expanded(
              child: filteredBooks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No books match "$_searchQuery"'
                                : 'No books available',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredBooks.length,
                      itemBuilder: (context, index) {
                        final book = filteredBooks[index];
                        if (_searchQuery.isNotEmpty) {
                          // Flat view during search
                          return _buildBookTile(
                            context: context,
                            book: book,
                            transactionService: transactionService,
                            currentBookId: currentBookId,
                            depth: 0,
                            isSearchMode: true,
                          );
                        } else {
                          // Recursive tree node view
                          return _buildBookTreeNode(
                            context: context,
                            book: book,
                            transactionService: transactionService,
                            currentBookId: currentBookId,
                            depth: 0,
                          );
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateBookDialog(transactionService),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Main Book'),
        backgroundColor: AppTheme.primarySeedColor,
      ),
    );
  }

  Widget _buildBookTreeNode({
    required BuildContext context,
    required Map<String, dynamic> book,
    required TransactionService transactionService,
    required String currentBookId,
    required int depth,
  }) {
    final id = book['id']?.toString() ?? '';
    final children = transactionService.getDirectSubBooks(id);
    final hasChildren = children.isNotEmpty;
    final isExpanded = !_collapsedBookIds.contains(id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBookTile(
          context: context,
          book: book,
          transactionService: transactionService,
          currentBookId: currentBookId,
          depth: depth,
          hasChildren: hasChildren,
          isExpanded: isExpanded,
          onToggleExpand: hasChildren ? () => _toggleExpand(id) : null,
        ),
        if (hasChildren && isExpanded)
          ...children.map(
            (child) => _buildBookTreeNode(
              context: context,
              book: child,
              transactionService: transactionService,
              currentBookId: currentBookId,
              depth: depth + 1,
            ),
          ),
      ],
    );
  }

  Widget _buildBookTile({
    required BuildContext context,
    required Map<String, dynamic> book,
    required TransactionService transactionService,
    required String currentBookId,
    required int depth,
    bool hasChildren = false,
    bool isExpanded = false,
    bool isSearchMode = false,
    VoidCallback? onToggleExpand,
  }) {
    final id = book['id']?.toString() ?? '';
    final name = book['name']?.toString() ?? 'Book';
    final isCurrent = id == currentBookId;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final directSubBooks = transactionService.getDirectSubBooks(id);

    return Padding(
      padding: EdgeInsets.only(
        left: isSearchMode ? 0 : depth * 16.0,
        bottom: 8.0,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent
                ? AppTheme.primarySeedColor
                : (isDark ? Colors.white12 : Colors.grey.shade200),
            width: isCurrent ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: isCurrent
              ? AppTheme.primarySeedColor.withValues(alpha: isDark ? 0.25 : 0.08)
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasChildren && !isSearchMode)
              InkWell(
                onTap: onToggleExpand,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_right_rounded,
                    color: AppTheme.primarySeedColor,
                    size: 22,
                  ),
                ),
              )
            else if (depth > 0 && !isSearchMode)
              const Padding(
                padding: EdgeInsets.only(right: 6.0),
                child: Icon(
                  Icons.subdirectory_arrow_right_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
              ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCurrent
                    ? AppTheme.primarySeedColor
                    : AppTheme.primarySeedColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasChildren
                    ? (isExpanded ? Icons.folder_open_rounded : Icons.folder_rounded)
                    : Icons.menu_book_rounded,
                color: isCurrent ? Colors.white : AppTheme.primarySeedColor,
                size: 20,
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                  fontSize: 15,
                  color: isCurrent
                      ? AppTheme.primarySeedColor
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primarySeedColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        subtitle: directSubBooks.isNotEmpty
            ? Text(
                '${directSubBooks.length} sub-book(s)',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              )
            : null,
        onTap: () async {
          if (!isCurrent) {
            await transactionService.switchBook(id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Switched to "$name"'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        },
        trailing: PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert_rounded,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            size: 20,
          ),
          onSelected: (value) async {
            if (value == 'select') {
              if (!isCurrent) {
                await transactionService.switchBook(id);
              }
            } else if (value == 'add_sub') {
              _showCreateSubBookDialog(
                transactionService,
                parentId: id,
                parentName: name,
              );
            } else if (value == 'rename') {
              _showRenameBookDialog(transactionService, id, name);
            } else if (value == 'delete') {
              _showDeleteBookDialog(transactionService, id, name);
            }
          },
          itemBuilder: (ctx) => [
            if (!isCurrent)
              const PopupMenuItem(
                value: 'select',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 18, color: AppTheme.primarySeedColor),
                    SizedBox(width: 10),
                    Text('Set Active Book'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'add_sub',
              child: Row(
                children: [
                  Icon(Icons.add_rounded, size: 18, color: AppTheme.primarySeedColor),
                  SizedBox(width: 10),
                  Text('Add Sub-Book'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Rename'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
}

  Future<void> _showCreateBookDialog(TransactionService transactionService) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Create New Main Book'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Book name (e.g. Shop, Personal)',
            ),
            onSubmitted: (value) => Navigator.of(ctx).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    final cleanName = (name ?? '').trim();
    if (cleanName.isEmpty) return;
    await transactionService.createBook(cleanName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created main book "$cleanName"')),
      );
    }
  }

  Future<void> _showCreateSubBookDialog(
    TransactionService transactionService, {
    required String parentId,
    required String parentName,
  }) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add Sub-Book'),
              const SizedBox(height: 2),
              Text(
                'Under: $parentName',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Sub-book name',
              prefixIcon: Icon(Icons.subdirectory_arrow_right_rounded, size: 18),
            ),
            onSubmitted: (value) => Navigator.of(ctx).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    final cleanName = (name ?? '').trim();
    if (cleanName.isEmpty) return;
    await transactionService.createSubBook(cleanName, parentId: parentId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sub-book "$cleanName" created under "$parentName"')),
      );
    }
  }

  Future<void> _showRenameBookDialog(
    TransactionService transactionService,
    String bookId,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Rename Book'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(hintText: 'New book name'),
            onSubmitted: (value) => Navigator.of(ctx).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final cleanName = (name ?? '').trim();
    if (cleanName.isEmpty || cleanName == currentName) return;
    final isDuplicate = transactionService.books.any(
      (book) =>
          book['id'] != bookId &&
          (book['name']?.toString().toLowerCase() ?? '') ==
              cleanName.toLowerCase(),
    );
    if (isDuplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Book name already exists. Choose another name.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await transactionService.renameBook(bookId, cleanName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Book renamed to "$cleanName"')),
      );
    }
  }

  Future<void> _showDeleteBookDialog(
    TransactionService transactionService,
    String bookId,
    String name,
  ) async {
    final subBooks = transactionService.getDirectSubBooks(bookId);
    final hasChildren = subBooks.isNotEmpty;
    final rootBooks = transactionService.rootBooks;
    final isRoot = !transactionService.books
        .any((b) => b['id'] == bookId && b['parentId'] != null);
    if (isRoot && rootBooks.length <= 1 && !hasChildren) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one book is required.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Book'),
          content: Text(
            hasChildren
                ? 'Delete "$name" and ALL its sub-books? This will permanently remove all transactions inside them.'
                : 'Delete "$name"? This will permanently remove all transactions and goals in this book.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;
    await transactionService.deleteBook(bookId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Book "$name" deleted')),
      );
    }
  }
}
