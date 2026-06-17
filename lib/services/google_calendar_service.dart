import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import '../models/race_model.dart';

class GoogleCalendarService {
  static const _scope = 'https://www.googleapis.com/auth/calendar.events';

  final GoogleSignIn _googleSignIn;

  GoogleCalendarService(this._googleSignIn);

  Future<void> addRace(Race race) async {
    final granted = await _googleSignIn.requestScopes([_scope]);
    if (!granted) throw Exception('Calendar permission denied');

    final account = _googleSignIn.currentUser;
    if (account == null) throw Exception('Not signed in');

    final headers = await account.authHeaders;
    final client = _AuthClient(headers);

    try {
      final api = gcal.CalendarApi(client);

      // Default to 9am start (UK standard for parkruns; reasonable for races)
      final start = DateTime(race.date.year, race.date.month, race.date.day, 9, 0);
      final end = start.add(const Duration(hours: 2));

      final description = [
        race.type,
        if (race.description != null && race.description!.isNotEmpty) race.description,
        if (race.website != null) race.website,
        'Added via RacePals',
      ].join('\n');

      final event = gcal.Event()
        ..summary = race.name
        ..location = race.location
        ..description = description
        ..start = (gcal.EventDateTime()
          ..dateTime = start
          ..timeZone = 'Europe/London')
        ..end = (gcal.EventDateTime()
          ..dateTime = end
          ..timeZone = 'Europe/London');

      await api.events.insert(event, 'primary');
    } finally {
      client.close();
    }
  }
}

class _AuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner;

  _AuthClient(this._headers) : _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
