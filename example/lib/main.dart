import 'package:flutter/material.dart';
import 'package:lazy_sticky_sections/lazy_sticky_sections.dart';

void main() => runApp(const ExampleApp());

/// Shows two long sectioned lists: a chat history with a header per day and
/// a contact list with a header per letter.
class ExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'lazy_sticky_sections',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const DefaultTabController(
        length: 2,
        child: Scaffold(
          bottomNavigationBar: Material(
            child: SafeArea(
              child: TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.chat_outlined), text: 'History'),
                  Tab(icon: Icon(Icons.people_outline), text: 'Contacts'),
                ],
              ),
            ),
          ),
          body: TabBarView(children: [HistoryPage(), ContactsPage()]),
        ),
      ),
    );
  }
}

/// Ten years of chat history: one section per day, with up to 400 messages
/// a day. About 3,650 sections and 300,000 messages, all built on demand.
class HistoryPage extends StatefulWidget {
  /// Creates the history page.
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const int dayCount = 3650;
  static final DateTime today = DateTime(2026, 10, 14);

  int? _currentDay;

  DateTime _dayAt(int section) => today.subtract(Duration(days: section));

  // A deterministic, uneven number of messages per day.
  int _messageCount(int section) {
    final mixed = (section * 2654435761) & 0xffffffff;
    return switch (mixed % 10) {
      0 => 0,
      < 7 => mixed % 30,
      _ => mixed % 400,
    };
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentDay;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          current == null ? 'History' : 'History · ${_label(_dayAt(current))}',
        ),
      ),
      body: LazyStickySectionsView(
        sectionCount: dayCount,
        itemCount: _messageCount,
        onCurrentSectionChanged: (section) =>
            setState(() => _currentDay = section),
        headerBuilder: (context, section) => DayHeader(
          label: _label(_dayAt(section)),
          messageCount: _messageCount(section),
        ),
        pinnedHeaderBuilder: (context, section) => DayHeader(
          label: _label(_dayAt(section)),
          messageCount: _messageCount(section),
          elevated: true,
        ),
        itemBuilder: (context, section, index) => MessageTile(
          text: 'Message ${index + 1} of ${_messageCount(section)}',
          mine: (section + index).isEven,
        ),
      ),
    );
  }

  String _label(DateTime day) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${day.day} ${months[day.month - 1]} ${day.year}';
  }
}

/// The header of one day in the chat history.
class DayHeader extends StatelessWidget {
  /// Creates a day header.
  const DayHeader({
    super.key,
    required this.label,
    required this.messageCount,
    this.elevated = false,
  });

  /// The date to show.
  final String label;

  /// The number of messages on this day.
  final int messageCount;

  /// Whether to draw a shadow, for the pinned copy of the header.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Material(
          color: colors.secondaryContainer,
          elevation: elevated ? 3 : 0,
          shape: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              messageCount == 0 ? '$label · no messages' : label,
              style: TextStyle(color: colors.onSecondaryContainer),
            ),
          ),
        ),
      ),
    );
  }
}

/// One chat message bubble.
class MessageTile extends StatelessWidget {
  /// Creates a message bubble.
  const MessageTile({super.key, required this.text, required this.mine});

  /// The message text.
  final String text;

  /// Whether the message was sent by this user, which aligns it to the end.
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: mine ? colors.primaryContainer : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text),
      ),
    );
  }
}

/// A contact list with a header per letter, below a pinned app bar.
class ContactsPage extends StatelessWidget {
  /// Creates the contacts page.
  const ContactsPage({super.key});

  static const List<String> _names = [
    'Ada', 'Ahmed', 'Alma', 'Ayesha', 'Bilal', 'Bruno', 'Chen', 'Clara', //
    'Dana', 'Diego', 'Elif', 'Emeka', 'Farah', 'Felix', 'Grace', 'Hana', //
    'Hugo', 'Ines', 'Ivan', 'Jun', 'Kofi', 'Lina', 'Luca', 'Maya', 'Mona', //
    'Nadia', 'Noor', 'Omar', 'Priya', 'Quinn', 'Rosa', 'Sami', 'Sara', //
    'Tariq', 'Uma', 'Vera', 'Wen', 'Xavi', 'Yara', 'Zane', 'Zoe',
  ];

  static final Map<String, List<String>> _byLetter = () {
    final groups = <String, List<String>>{};
    for (final name in _names) {
      for (var n = 1; n <= 12; n++) {
        groups.putIfAbsent(name[0], () => []).add('$name $n');
      }
    }
    return groups;
  }();

  static final List<String> _letters = _byLetter.keys.toList()..sort();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        const SliverAppBar.large(pinned: true, title: Text('Contacts')),
        SliverLazyStickySections(
          sectionCount: _letters.length,
          itemCount: (section) => _byLetter[_letters[section]]!.length,
          headerBuilder: (context, section) => Container(
            color: colors.surfaceContainer,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              _letters[section],
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          itemBuilder: (context, section, index) {
            final name = _byLetter[_letters[section]]![index];
            return ListTile(
              leading: CircleAvatar(child: Text(name[0])),
              title: Text(name),
            );
          },
        ),
      ],
    );
  }
}
