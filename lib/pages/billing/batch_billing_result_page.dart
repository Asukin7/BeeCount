import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/db.dart' as db;
import '../../l10n/app_localizations.dart';
import '../../pages/attachment/attachment_preview_page.dart';
import '../../pages/tag/tag_detail_page.dart';
import '../../pages/transaction/category_detail_page.dart';
import '../../providers.dart';
import '../../services/billing/post_processor.dart';
import '../../styles/tokens.dart';
import '../../utils/category_utils.dart';
import '../../utils/transaction_edit_utils.dart';
import '../../widgets/biz/day_section_header.dart';
import '../../widgets/biz/transaction_list_item.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/ui/ui.dart';

/// 识别结果页。
///
/// OCR 识别后已入库，本页从数据库加载完整的交易展示数据，
/// 显示效果与首页明细列表完全一致。
/// 点击复用 TransactionEditUtils.editTransaction 编辑，
/// 左滑删除调用 repo.deleteTransaction。
class BatchBillingResultPage extends ConsumerStatefulWidget {
  /// 已入库的交易ID列表，null 表示该张图片未识别成功
  final List<int?> transactionIds;

  const BatchBillingResultPage({super.key, required this.transactionIds});

  @override
  ConsumerState<BatchBillingResultPage> createState() =>
      _BatchBillingResultPageState();
}

/// 单条已入库交易的完整展示数据
class _TransactionEntry {
  final int transactionId;
  db.Transaction? transaction;
  db.Category? category;
  List<db.Tag> tags;
  int attachmentCount;
  String? accountName;
  String? toAccountName;
  bool isDeleted;

  _TransactionEntry({
    required this.transactionId,
    this.transaction,
    this.category,
    this.tags = const [],
    this.attachmentCount = 0,
    this.accountName,
    this.toAccountName,
    this.isDeleted = false,
  });
}

class _BatchBillingResultPageState
    extends ConsumerState<BatchBillingResultPage> {
  late List<_TransactionEntry?> _entries;
  /// 扁平化列表：元组格式，与首页 TransactionList 统一
  /// ('header', dateKey, List<int>)  — 日期分组头
  /// ('transaction', entryIndex, List<int>) — 交易项
  /// ('unrecognized', entryIndex, null) — 未识别项
  List<dynamic> _flatItems = [];

  @override
  void initState() {
    super.initState();
    _entries = widget.transactionIds.map((id) {
      if (id != null) {
        return _TransactionEntry(transactionId: id);
      }
      return null;
    }).toList();
    _loadAllEntries();
  }

  /// 从数据库加载所有已入库交易的完整数据
  Future<void> _loadAllEntries() async {
    final repo = ref.read(repositoryProvider);

    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (entry == null || entry.isDeleted) continue;

      try {
        final t = await repo.getTransactionById(entry.transactionId);
        if (t == null) continue;

        // 分类
        db.Category? cat;
        if (t.categoryId != null) {
          cat = await repo.getCategoryById(t.categoryId!);
        }

        // 标签
        final tags = await repo.getTagsForTransaction(t.id);

        // 附件数量
        final attachmentCount = await repo.getAttachmentCountByTransaction(t.id);

        // 账户名称
        String? accountName;
        String? toAccountName;
        if (t.accountId != null) {
          final account = await repo.getAccount(t.accountId!);
          accountName = account?.name;
        }
        if (t.toAccountId != null) {
          final toAccount = await repo.getAccount(t.toAccountId!);
          toAccountName = toAccount?.name;
        }

        entry.transaction = t;
        entry.category = cat;
        entry.tags = tags;
        entry.attachmentCount = attachmentCount;
        entry.accountName = accountName;
        entry.toAccountName = toAccountName;
      } catch (_) {}
    }

    if (mounted) {
      _buildFlatItems();
      setState(() {});
    }
  }

  /// 构建扁平化列表：按日期分组，元组格式与首页 TransactionList 统一
  void _buildFlatItems() {
    final dateFmt = DateFormat('yyyy-MM-dd');

    // 按日期分组已入库交易
    final groups = <String, List<int>>{}; // dateKey → entry indices
    final unrecognizedIndices = <int>[];

    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (entry == null) {
        unrecognizedIndices.add(i);
        continue;
      }
      if (entry.isDeleted || entry.transaction == null) continue;

      final dt = entry.transaction!.happenedAt.toLocal();
      final key = dateFmt.format(DateTime(dt.year, dt.month, dt.day));
      groups.putIfAbsent(key, () => []).add(i);
    }

    // 日期降序排列
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    _flatItems = <dynamic>[];

    for (final key in sortedKeys) {
      final list = groups[key]!;
      // 添加日期头部
      _flatItems.add(('header', key, list));
      // 添加该日所有交易项
      for (final idx in list) {
        _flatItems.add(('transaction', idx, list));
      }
    }

    // 未识别项放在最后
    for (final idx in unrecognizedIndices) {
      _flatItems.add(('unrecognized', idx, null));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasActive =
        _entries.any((e) => e != null && !e.isDeleted);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.batchBillingTitle,
            showBack: true,
          ),
          Expanded(
            child: !hasActive
                ? Center(child: Text(l10n.batchBillingEmpty))
                : Column(
                    children: [
                      Expanded(
                        child: MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: _flatItems.length,
                            itemBuilder: (context, index) {
                              final item = _flatItems[index];
                              final type = item.$1 as String;

                              // 日期分组头
                              if (type == 'header') {
                                final dateKey = item.$2 as String;
                                final list = item.$3 as List<int>;
                                double dayIncome = 0, dayExpense = 0;
                                for (final idx in list) {
                                  final t = _entries[idx]!.transaction!;
                                  if (t.type == 'income') dayIncome += t.amount;
                                  if (t.type == 'expense') {
                                    dayExpense += t.amount;
                                  }
                                }
                                final isFirst = index == 0;

                                return Column(
                                  children: [
                                    if (!isFirst && BeeTokens.cardInnerDividerHeight(context) > 0)
                                      Divider(
                                        height: BeeTokens.cardInnerDividerHeight(context),
                                        color: BeeTokens.cardInnerDividerColor(context),
                                      ),
                                    DaySectionHeader(
                                      dateText: dateKey,
                                      income: dayIncome,
                                      expense: dayExpense,
                                    ),
                                  ],
                                );
                              }

                              // 未识别项
                              if (type == 'unrecognized') {
                                final entryIndex = item.$2 as int;
                                final entry = _entries[entryIndex];
                                if (entry != null) {
                                  return const SizedBox.shrink();
                                }
                                return Dismissible(
                                  key: ValueKey(
                                      'batch_unrecognized_$entryIndex'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding:
                                        const EdgeInsets.only(right: 20),
                                    color:
                                        Theme.of(context).colorScheme.error,
                                    child: Icon(
                                      Icons.delete_outline,
                                      color:
                                          Theme.of(context).colorScheme.onError,
                                    ),
                                  ),
                                  confirmDismiss: (_) =>
                                      AppDialog.confirm<bool>(
                                    context,
                                    title: l10n.deleteConfirmTitle,
                                    message: l10n.deleteConfirmMessage,
                                  ),
                                  onDismissed: (_) {
                                    setState(() {
                                      _entries[entryIndex] = null;
                                      _buildFlatItems();
                                    });
                                  },
                                  child: InkWell(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error
                                                  .withValues(alpha: 0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.error_outline,
                                              size: 18,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              l10n.batchBillingUnrecognized,
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // 交易项
                              if (type == 'transaction') {
                                final entryIndex = item.$2 as int;
                                final allItemsInDay = item.$3 as List<int>;
                                final entry = _entries[entryIndex];
                                if (entry == null || entry.isDeleted) {
                                  return const SizedBox.shrink();
                                }
                                final it = (t: entry.transaction!, category: entry.category);
                                final isTransfer = it.t.type == 'transfer';
                                final isExpense = it.t.type == 'expense';
                                final isAdjustment = it.t.type == 'adjustment';

                                // 获取分类显示名称
                                final categoryName = isAdjustment
                                    ? AppLocalizations.of(context).adjustmentTransaction
                                    : CategoryUtils.getDisplayName(it.category?.name, context);

                                final subtitle = it.t.note ?? '';

                                // 检查是否是当天最后一项
                                final isLastInGroup = allItemsInDay.last == entryIndex;

                                // 获取账户名称（仅在账户功能启用且有账户ID时）
                                final accountFeatureEnabled = ref.watch(accountFeatureEnabledProvider).valueOrNull ?? true;
                                String? accountName;
                                String? toAccountName;

                                if (accountFeatureEnabled && it.t.accountId != null) {
                                  accountName = entry.accountName;
                                  if (isTransfer && it.t.toAccountId != null) {
                                    toAccountName = entry.toAccountName;
                                  }
                                }

                                return Dismissible(
                                  key: Key('tx-${it.t.id}-$index'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 16),
                                    color: Colors.red,
                                    child: const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  confirmDismiss: (direction) async {
                                    return await AppDialog.confirm<bool>(
                                          context,
                                          title: AppLocalizations.of(context).deleteConfirmTitle,
                                          message: AppLocalizations.of(context).deleteConfirmMessage,
                                        ) ??
                                        false;
                                  },
                                  onDismissed: (direction) async {
                                    await _deleteEntry(entryIndex);
                                  },
                                  child: Column(
                                    children: [
                                      Builder(
                                        builder: (context) {
                                          // 获取该交易的标签
                                          final transactionTags = entry.tags;
                                          final tagsList = transactionTags
                                              .map((t) => (id: t.id, name: t.name, color: t.color))
                                              .toList();

                                          // 转账账户信息
                                          final transferAccountInfo = (accountName != null && toAccountName != null)
                                              ? '$accountName → $toAccountName'
                                              : null;

                                          // 获取附件数量
                                          final attachmentCount = entry.attachmentCount;

                                          return TransactionListItem(
                                            icon: isAdjustment
                                              ? Icons.tune
                                              : getCategoryIconData(category: it.category, categoryName: categoryName),
                                            category: isAdjustment ? null : it.category,
                                            title: isTransfer
                                              ? (subtitle.isNotEmpty ? subtitle : AppLocalizations.of(context).transferTitle)
                                              : isAdjustment
                                                ? categoryName
                                                : (subtitle.isNotEmpty ? subtitle : categoryName),
                                            categoryName: (isTransfer || isAdjustment)
                                              ? null
                                              : (subtitle.isNotEmpty ? null : categoryName),
                                            amount: it.t.amount,
                                            isExpense: isExpense,
                                            isTransfer: isTransfer,
                                            isAdjustment: isAdjustment,
                                            happenedAt: it.t.happenedAt,
                                            accountName: isTransfer
                                              ? transferAccountInfo
                                              : accountName,
                                            tags: tagsList.isNotEmpty ? tagsList : null,
                                            attachmentCount: attachmentCount,
                                            onAttachmentTap: attachmentCount > 0
                                                ? () async {
                                                    await Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) => AttachmentPreviewPage.fromTransaction(
                                                          transactionId: it.t.id,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                : null,
                                            onTagTap: (tagId, tagName) async {
                                              await Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => TagDetailPage(
                                                    tagId: tagId,
                                                    tagName: tagName,
                                                  ),
                                                ),
                                              );
                                            },
                                            onTap: () async {
                                              await TransactionEditUtils.editTransaction(
                                                context,
                                                ref,
                                                it.t,
                                                it.category,
                                              );
                                              await _reloadEntry(entryIndex);
                                            },
                                            onCategoryTap: !isTransfer && it.category?.id != null
                                                ? () async {
                                                    await Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) => CategoryDetailPage(
                                                          categoryId: it.category!.id,
                                                          categoryName: categoryName,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                : null,
                                          );
                                        },
                                      ),
                                      if (!isLastInGroup)
                                        BeeDivider.short(indent: 56 + 16, endIndent: 16),
                                    ],
                                  ),
                                );
                              }

                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 重新加载单条数据
  Future<void> _reloadEntry(int index) async {
    final entry = _entries[index];
    if (entry == null) return;

    final repo = ref.read(repositoryProvider);
    final t = await repo.getTransactionById(entry.transactionId);
    if (t == null) {
      // 交易已被删除（编辑页中删除了）
      if (mounted) {
        setState(() {
          entry.isDeleted = true;
          _buildFlatItems();
        });
      }
      return;
    }

    // 刷新分类
    db.Category? cat;
    if (t.categoryId != null) {
      cat = await repo.getCategoryById(t.categoryId!);
    }

    // 刷新标签
    final tags = await repo.getTagsForTransaction(t.id);

    // 刷新附件数量
    final attachmentCount =
        await repo.getAttachmentCountByTransaction(t.id);

    // 刷新账户
    String? accountName;
    String? toAccountName;
    if (t.accountId != null) {
      final account = await repo.getAccount(t.accountId!);
      accountName = account?.name;
    }
    if (t.toAccountId != null) {
      final toAccount = await repo.getAccount(t.toAccountId!);
      toAccountName = toAccount?.name;
    }

    if (!mounted) return;
    setState(() {
      entry.transaction = t;
      entry.category = cat;
      entry.tags = tags;
      entry.attachmentCount = attachmentCount;
      entry.accountName = accountName;
      entry.toAccountName = toAccountName;
      _buildFlatItems();
    });
  }

  /// 删除已入库的交易
  Future<void> _deleteEntry(int index) async {
    final entry = _entries[index];
    if (entry == null) return;

    if (entry.transactionId != 0) {
      final repo = ref.read(repositoryProvider);
      await repo.deleteTransaction(entry.transactionId);
      final ledgerId = ref.read(currentLedgerIdProvider);
      PostProcessor.sync(ref, ledgerId: ledgerId);
    }
    setState(() {
      entry.isDeleted = true;
      _buildFlatItems();
    });
  }

}
