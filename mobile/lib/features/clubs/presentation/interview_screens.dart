import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:material_ui/material_ui.dart';

List<JsonObject> _items(JsonObject data, String key) =>
    (data[key] as List).cast<JsonObject>();

String _utcTime(String raw) {
  final utc = DateTime.parse(raw).toUtc();
  return '${_dateKey(utc)} ${_clock(utc.hour * 60 + utc.minute)} UTC';
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _clock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

class _InterviewPage extends StatefulWidget {
  const _InterviewPage({
    required this.title,
    required this.load,
    required this.children,
  });

  final String title;
  final Future<JsonObject> Function(CampusApi, String) load;
  final List<Widget> Function(
    BuildContext,
    JsonObject,
    bool,
    Future<void> Function(Future<void> Function(CampusApi, String)),
  )
  children;

  @override
  State<_InterviewPage> createState() => _InterviewPageState();
}

class _InterviewPageState extends State<_InterviewPage> {
  JsonObject? _data;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _run();
    });
  }

  Future<void> _run([Future<void> Function(CampusApi, String)? action]) async {
    final session = StudentSessionScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (action != null) {
        await session.authenticated((token) => action(session.api, token));
      }
      final data = await session.authenticated(
        (token) => widget.load(session.api, token),
      );
      if (mounted) _data = data;
    } on ApiFailure catch (error) {
      _error = error.message;
    } catch (_) {
      _error = 'Could not load the interview information.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = StudentSessionScope.of(context).signedIn;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Refresh interviews',
            onPressed: _busy || !signedIn ? null : () => _run(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!signedIn)
              const Text('Sign in again to view interviews.')
            else ...[
              if (_busy) const LinearProgressIndicator(),
              if (_error != null) ...[
                Text(_error!),
                TextButton(
                  onPressed: _busy ? null : () => _run(),
                  child: const Text('Refresh and retry'),
                ),
              ],
              if (_data case final data?)
                ...widget.children(
                  context,
                  data,
                  _busy,
                  (action) => _run(action),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class StudentInterviewScreen extends StatelessWidget {
  const StudentInterviewScreen(this.application, {super.key});
  final MembershipApplication application;

  @override
  Widget build(BuildContext context) => _InterviewPage(
    title: 'Interview · ${application.clubName}',
    load: (api, token) => api.studentInterview(token, application.id),
    children: (context, data, busy, change) {
      final booking = data['booking'] as JsonObject?;
      final confirmed = booking?['status'] == 'confirmed';
      final days = _items(data, 'days');
      return [
        if (confirmed) ...[
          const Text('Confirmed interview'),
          Text(_utcTime(booking!['starts_at'] as String)),
          Text('Ends ${_utcTime(booking['ends_at'] as String)}'),
        ] else ...[
          if (booking != null) ...[
            Text('Day selected · ${booking['day']} UTC'),
            const Text('Appointment status · Unscheduled'),
            const Text(
              'Your appointment time will appear after the club publishes it.',
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => change(
                      (api, token) =>
                          api.withdrawInterviewDay(token, application.id),
                    ),
              child: const Text('Withdraw day selection'),
            ),
          ],
          const SizedBox(height: 12),
          const Text('Choose an interview day (UTC)'),
          if (days.isEmpty) const Text('No available interview days.'),
          for (final day in days)
            ListTile(
              title: Text(day['day'] as String),
              subtitle: Text(
                day['seats_available'] == 0
                    ? 'Full'
                    : '${day['seats_available']} places available',
              ),
              trailing: booking?['day_id'] == day['id']
                  ? const Icon(Icons.check)
                  : null,
              enabled:
                  !busy &&
                  day['seats_available'] != 0 &&
                  booking?['day_id'] != day['id'],
              onTap: () => change(
                (api, token) => api.selectInterviewDay(
                  token,
                  application.id,
                  day['id'] as String,
                ),
              ),
            ),
        ],
      ];
    },
  );
}

class AdminInterviewDaysScreen extends StatelessWidget {
  const AdminInterviewDaysScreen(this.club, {super.key});
  final ManagedClub club;

  @override
  Widget build(BuildContext context) => _InterviewPage(
    title: 'Interview Days',
    load: (api, token) => api.interviewDays(token, club.id),
    children: (context, data, busy, change) {
      Future<void> edit([JsonObject? day]) async {
        final setup = await Navigator.of(context)
            .push<({String date, JsonObject data})>(
              MaterialPageRoute(builder: (_) => _DayForm(day)),
            );
        if (setup == null || !context.mounted) return;
        await change((api, token) async {
          await api.saveInterviewDay(token, club.id, setup.date, setup.data);
        });
      }

      final days = _items(data, 'days');
      return [
        Text(club.name, style: Theme.of(context).textTheme.titleLarge),
        FilledButton(
          onPressed: busy ? null : () => edit(),
          child: const Text('Publish interview day'),
        ),
        if (days.isEmpty) const Text('No interview days have been published.'),
        for (final day in days)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${day['day']} UTC'),
                  Text(
                    '${day['selected']} of ${day['capacity']} places selected',
                  ),
                  Text('Minimum duration · ${day['duration_minutes']} min'),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: busy ? null : () => edit(day),
                        child: const Text('Edit day and availability'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => _ScheduleScreen(club, day),
                                ),
                              ),
                        child: const Text('Generate schedule'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ];
    },
  );
}

class _DayForm extends StatefulWidget {
  const _DayForm(this.day);
  final JsonObject? day;

  @override
  State<_DayForm> createState() => _DayFormState();
}

class _DayFormState extends State<_DayForm> {
  late String? _date = widget.day?['day'] as String?;
  late final _capacity = TextEditingController(
    text: widget.day?['capacity']?.toString(),
  );
  late final _duration = TextEditingController(
    text: widget.day?['duration_minutes']?.toString(),
  );
  late final _periods = TextEditingController(
    text: widget.day == null
        ? ''
        : _items(widget.day!, 'periods')
              .map(
                (p) =>
                    '${_clock(p['start_minute'] as int)}-${_clock(p['end_minute'] as int)}',
              )
              .join('\n'),
  );
  String? _error;

  @override
  void dispose() {
    _capacity.dispose();
    _duration.dispose();
    _periods.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now().toUtc();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
    );
    if (mounted && date != null) setState(() => _date = _dateKey(date));
  }

  int _minute(String hour, String minute) {
    final h = int.parse(hour);
    final m = int.parse(minute);
    if (m > 59 || h > 24 || (h == 24 && m > 0)) throw const FormatException();
    return h * 60 + m;
  }

  void _save() {
    final date = _date;
    final capacity = int.tryParse(_capacity.text.trim());
    final duration = int.tryParse(_duration.text.trim());
    if (date == null ||
        capacity == null ||
        capacity < 1 ||
        duration == null ||
        duration < 1 ||
        duration > 1440) {
      setState(
        () => _error = 'Choose a date, set a positive capacity, and enter a duration from 1 to 1440 minutes.',
      );
      return;
    }
    final periods = <JsonObject>[];
    try {
      for (final line
          in _periods.text
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)) {
        final match = RegExp(r'^(\d{2}):(\d{2})\s*-\s*(\d{2}):(\d{2})$')
            .firstMatch(line);
        if (match == null) throw const FormatException();
        final start = _minute(match[1]!, match[2]!);
        final end = _minute(match[3]!, match[4]!);
        if (end - start < duration) throw const FormatException();
        periods.add({'start_minute': start, 'end_minute': end});
      }
      periods.sort(
        (a, b) =>
            (a['start_minute'] as int).compareTo(b['start_minute'] as int),
      );
      for (var i = 1; i < periods.length; i++) {
        if ((periods[i]['start_minute'] as int) <
            (periods[i - 1]['end_minute'] as int)) {
          throw const FormatException();
        }
      }
    } on FormatException {
      setState(
        () => _error = 'Use nonoverlapping HH:MM-HH:MM periods that fit the interview duration.',
      );
      return;
    }
    Navigator.of(context).pop((
      date: date,
      data: <String, dynamic>{
        'capacity': capacity,
        'duration_minutes': duration,
        'periods': periods,
      },
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.day == null ? 'Publish Interview Day' : 'Edit Interview Day',
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          OutlinedButton(
            onPressed: widget.day == null ? _pickDate : null,
            child: Text(_date == null ? 'Choose date (UTC)' : '$_date UTC'),
          ),
          TextField(
            controller: _capacity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Maximum applicants'),
          ),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Minimum interview duration in minutes',
            ),
          ),
          TextField(
            controller: _periods,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Availability in UTC',
              helperText: 'One period per line, e.g. 09:00-11:00',
            ),
          ),
          if (_error case final error?) Text(error),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            child: const Text('Save interview day'),
          ),
        ],
      ),
    ),
  );
}

class _ScheduleScreen extends StatefulWidget {
  const _ScheduleScreen(this.club, this.day);
  final ManagedClub club;
  final JsonObject day;

  @override
  State<_ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<_ScheduleScreen> {
  final _unchecked = <String>{};

  @override
  Widget build(BuildContext context) => _InterviewPage(
    title: 'Schedule · ${widget.day['day']}',
    load: (api, token) => api.interviewSchedule(
      token,
      widget.club.id,
      widget.day['id'] as String,
    ),
    children: (context, data, busy, change) {
      final slots = _items(data, 'slots');
      final publishable = slots
          .where(
            (slot) =>
                slot['status'] == 'proposed' &&
                !_unchecked.contains(slot['selection_id']),
          )
          .toList();
      return [
        if (slots.isEmpty)
          const Text('No eligible students have selected this day.'),
        for (final slot in slots)
          if (slot['status'] == 'proposed')
            CheckboxListTile(
              value: !_unchecked.contains(slot['selection_id']),
              title: Text(slot['applicant_name'] as String),
              subtitle: Text(
                'Proposed · ${_utcTime(slot['starts_at'] as String)}',
              ),
              onChanged: busy
                  ? null
                  : (checked) => setState(() {
                      final id = slot['selection_id'] as String;
                      if (checked == true) {
                        _unchecked.remove(id);
                      } else {
                        _unchecked.add(id);
                      }
                    }),
            )
          else
            ListTile(
              title: Text(slot['applicant_name'] as String),
              subtitle: Text(
                slot['status'] == 'confirmed'
                    ? 'Confirmed · ${_utcTime(slot['starts_at'] as String)}'
                    : 'Unscheduled',
              ),
            ),
        if (publishable.isNotEmpty)
          FilledButton(
            onPressed: busy
                ? null
                : () => change(
                    (api, token) => api.publishInterviews(
                      token,
                      widget.club.id,
                      widget.day['id'] as String,
                      [
                        for (final slot in publishable)
                          {
                            'selection_id': slot['selection_id'],
                            'starts_at': slot['starts_at'],
                            'ends_at': slot['ends_at'],
                          },
                      ],
                    ),
                  ),
            child: Text('Publish ${publishable.length} selected appointments'),
          ),
      ];
    },
  );
}

class InterviewAppointmentsScreen extends StatelessWidget {
  const InterviewAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) => _InterviewPage(
    title: 'Interview Calendar',
    load: (api, token) => api.interviewAppointments(token),
    children: (context, data, busy, change) {
      final items = _items(data, 'appointments');
      return [
        if (items.isEmpty) const Text('No confirmed interviews yet.'),
        for (final item in items)
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_available_outlined),
              title: Text(item['club_name'] as String),
              subtitle: Text(
                '${item['notice']}\n${_utcTime(item['starts_at'] as String)}'
                '\nEnds ${_utcTime(item['ends_at'] as String)}',
              ),
            ),
          ),
      ];
    },
  );
}
