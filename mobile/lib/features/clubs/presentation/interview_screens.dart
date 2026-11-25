import 'package:campusconnect/app/app.dart';
import 'package:campusconnect/core/api_client.dart';
import 'package:material_ui/material_ui.dart';

List<JsonObject> _items(JsonObject data, String key) =>
    (data[key] as List).cast<JsonObject>();

String _statusLabel(Object? status) => switch (status) {
  'confirmed' => 'Confirmed',
  'attended' => 'Attended',
  'no_show' => 'No-show',
  'cancelled' => 'Cancelled',
  'expired' => 'Expired',
  _ => 'Unscheduled',
};

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
  StudentInterviewScreen(MembershipApplication application, {super.key})
    : applicationId = application.id,
      clubName = application.clubName;
  const StudentInterviewScreen.forApplication(
    this.applicationId,
    this.clubName, {
    super.key,
  });
  final String applicationId;
  final String clubName;

  @override
  Widget build(BuildContext context) => _InterviewPage(
    title: 'Interview · $clubName',
    load: (api, token) => api.studentInterview(token, applicationId),
    children: (context, data, busy, change) {
      final booking = data['booking'] as JsonObject?;
      final status = booking?['status'];
      final hasAppointment = {
        'confirmed',
        'attended',
        'no_show',
      }.contains(status);
      final waiting = status == 'unscheduled';
      final days = _items(data, 'days');
      return [
        if (hasAppointment) ...[
          Text('${_statusLabel(status)} interview'),
          Text(_utcTime(booking!['starts_at'] as String)),
          Text('Ends ${_utcTime(booking['ends_at'] as String)}'),
        ] else ...[
          if (status == 'cancelled') ...[
            const Text('Interview cancelled.'),
            if (booking?['day'] case final String day) Text('Day: $day UTC'),
            if (booking?['starts_at'] case final String startsAt)
              Text('Scheduled: ${_utcTime(startsAt)}'),
            if (booking?['cancellation_reason'] case final String reason)
              Text(reason),
          ],
          if (status == 'expired')
            const Text(
              'Your interview day expired without an appointment. Choose another day.',
            ),
          if (waiting && booking != null) ...[
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
                          api.withdrawInterviewDay(token, applicationId),
                    ),
              child: const Text('Withdraw day selection'),
            ),
          ],
          if (days.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Choose an interview day (UTC)'),
          ],
          if (days.isEmpty ||
              (!waiting && days.every((day) => day['seats_available'] == 0)))
            const Text('No Available Days'),
          for (final day in days)
            ListTile(
              title: Text(day['day'] as String),
              subtitle: Text(
                day['seats_available'] == 0
                    ? 'Full'
                    : '${day['seats_available']} places available',
              ),
              trailing: waiting && booking?['day_id'] == day['id']
                  ? const Icon(Icons.check)
                  : null,
              enabled:
                  !busy &&
                  day['seats_available'] != 0 &&
                  (!waiting || booking?['day_id'] != day['id']),
              onTap: () => change(
                (api, token) => api.selectInterviewDay(
                  token,
                  applicationId,
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
                  if (day['cancelled'] == true) const Text('Cancelled'),
                  Text(
                    '${day['selected']} of ${day['capacity']} places selected',
                  ),
                  Text('Minimum duration · ${day['duration_minutes']} min'),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: busy || day['cancelled'] == true
                            ? null
                            : () => edit(day),
                        child: const Text('Edit day and availability'),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => _ScheduleScreen(club, day),
                                  ),
                                );
                                if (context.mounted) {
                                  await change((_, _) async {});
                                }
                              },
                        child: Text(
                          day['cancelled'] == true
                              ? 'View history'
                              : 'Generate schedule',
                        ),
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
      final cancelled = data['cancelled'] == true;
      final club = widget.club.id;
      final day = widget.day['id'] as String;
      Future<void> cancel(JsonObject target) async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => _CancelInterviewScreen(club, day, target),
          ),
        );
        if (changed == true && context.mounted) await change((_, _) async {});
      }

      final publishable = slots
          .where(
            (slot) =>
                slot['status'] == 'proposed' &&
                !_unchecked.contains(slot['selection_id']),
          )
          .toList();
      return [
        if (cancelled)
          const Text('Interview day cancelled')
        else ...[
          OutlinedButton(
            onPressed: busy ? null : () => cancel({'scope': 'day'}),
            child: const Text('Cancel entire day'),
          ),
          for (final period in _items(data, 'periods'))
            TextButton(
              onPressed: busy
                  ? null
                  : () => cancel({'scope': 'period', 'period': period}),
              child: Text(
                'Cancel period ${_clock(period['start_minute'] as int)}–'
                '${_clock(period['end_minute'] as int)} UTC',
              ),
            ),
        ],
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: Text(slot['applicant_name'] as String),
                  subtitle: Text(
                    [
                      _statusLabel(slot['status']),
                      if (slot['starts_at'] case final String start)
                        _utcTime(start),
                      if (slot['cancellation_reason'] case final String reason)
                        reason,
                    ].join('\n'),
                  ),
                ),
                if (slot['status'] == 'confirmed')
                  Wrap(
                    children: [
                      if (!cancelled)
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => cancel({
                                  'scope': 'appointment',
                                  'selection_id': slot['selection_id'],
                                }),
                          child: const Text('Cancel appointment'),
                        ),
                      if (slot['ends_at'] case final String end)
                        if (!DateTime.parse(end).isAfter(DateTime.now()))
                          for (final status in ['attended', 'no_show'])
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final yes = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(
                                            'Record ${_statusLabel(status)}?',
                                          ),
                                          content: Text(
                                            slot['applicant_name'] as String,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Back'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text(
                                                'Record attendance',
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (yes == true && context.mounted) {
                                        await change(
                                          (api, token) =>
                                              api.recordInterviewAttendance(
                                                token,
                                                club,
                                                day,
                                                slot['selection_id'] as String,
                                                status,
                                              ),
                                        );
                                      }
                                    },
                              child: Text('Record ${_statusLabel(status)}'),
                            ),
                    ],
                  ),
              ],
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
        if (_items(data, 'cancellations').isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Cancellation history'),
          for (final audit in _items(data, 'cancellations'))
            ListTile(
              title: Text(audit['reason'] as String),
              subtitle: Text(_utcTime(audit['created_at'] as String)),
            ),
        ],
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
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const InterviewNoticesScreen(),
            ),
          ),
          child: const Text('Interview notifications'),
        ),
        if (items.isEmpty) const Text('No interview appointments yet.'),
        for (final item in items)
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_available_outlined),
              title: Text(item['club_name'] as String),
              subtitle: Text(
                [
                  _statusLabel(item['status']),
                  if (item['starts_at'] case final String start)
                    _utcTime(start)
                  else
                    '${item['day']} UTC',
                  if (item['ends_at'] case final String end)
                    'Ends ${_utcTime(end)}',
                  if (item['cancellation_reason'] case final String reason)
                    reason,
                ].join('\n'),
              ),
              onTap: () => _openBooking(context, item),
            ),
          ),
      ];
    },
  );
}

void _openBooking(BuildContext context, JsonObject item) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => StudentInterviewScreen.forApplication(
        item['application_id'] as String,
        item['club_name'] as String,
      ),
    ),
  );
}

class InterviewNoticesScreen extends StatelessWidget {
  const InterviewNoticesScreen({super.key});

  @override
  Widget build(BuildContext context) => _InterviewPage(
    title: 'Interview Notifications',
    load: (api, token) => api.interviewNotices(token),
    children: (context, data, busy, change) {
      final notices = _items(data, 'notices');
      return [
        if (notices.isEmpty) const Text('No interview notifications yet.'),
        for (final notice in notices)
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(notice['message'] as String),
              subtitle: Text(_utcTime(notice['created_at'] as String)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openBooking(context, notice),
            ),
          ),
      ];
    },
  );
}

class _CancelInterviewScreen extends StatefulWidget {
  const _CancelInterviewScreen(this.club, this.day, this.target);
  final String club, day;
  final JsonObject target;

  @override
  State<_CancelInterviewScreen> createState() => _CancelInterviewScreenState();
}

class _CancelInterviewScreenState extends State<_CancelInterviewScreen> {
  final _reason = TextEditingController();
  Future<JsonObject>? _preview;
  bool _submitting = false;
  bool _stale = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preview ??= _fetch();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<JsonObject> _fetch() {
    final session = StudentSessionScope.of(context);
    return session.authenticated(
      (token) => session.api.previewInterviewCancellation(
        token,
        widget.club,
        widget.day,
        widget.target,
      ),
    );
  }

  void _refresh() => setState(() {
    _preview = _fetch();
    _error = null;
    _stale = false;
  });

  Future<void> _cancel(String previewToken) async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Enter a reason the affected students can see.');
      return;
    }
    final session = StudentSessionScope.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await session.authenticated(
        (token) => session.api.cancelInterview(
          token,
          widget.club,
          widget.day,
          widget.target,
          previewToken,
          reason,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Cancellation saved.')));
      Navigator.pop(context, true);
    } on ApiFailure catch (error) {
      _error = error.message;
      _stale = error.statusCode == 409;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Confirm Interview Cancellation')),
    body: FutureBuilder<JsonObject>(
      future: _preview,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(snapshot.error.toString()),
                TextButton(onPressed: _refresh, child: const Text('Try again')),
              ],
            ),
          );
        }
        final data = snapshot.data!;
        final affected = _items(data, 'affected');
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('${affected.length} affected students'),
            if (affected.isEmpty) const Text('No students will be notified.'),
            for (final item in affected)
              ListTile(
                title: Text(item['applicant_name'] as String),
                subtitle: Text(_statusLabel(item['status'])),
              ),
            TextField(
              controller: _reason,
              enabled: !_submitting,
              maxLength: 1000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Cancellation reason shown to students',
              ),
            ),
            if (_error case final error?) Text(error),
            if (_stale)
              TextButton(
                onPressed: _refresh,
                child: const Text('Refresh affected students'),
              ),
            if (_submitting) const LinearProgressIndicator(),
            FilledButton(
              onPressed: _submitting || _stale
                  ? null
                  : () => _cancel(data['preview_token'] as String),
              child: const Text('Confirm cancellation'),
            ),
          ],
        );
      },
    ),
  );
}
