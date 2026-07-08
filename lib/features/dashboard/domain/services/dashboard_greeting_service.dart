import 'dashboard_greeting.dart';

final class DashboardGreetingService {
  const DashboardGreetingService();

  DashboardGreeting getGreeting(DateTime dateTime) {
    final hour = dateTime.hour;

    if (hour >= 5 && hour < 12) {
      return DashboardGreeting.morning;
    }

    if (hour >= 12 && hour < 18) {
      return DashboardGreeting.afternoon;
    }

    if (hour >= 18 && hour < 23) {
      return DashboardGreeting.evening;
    }

    return DashboardGreeting.night;
  }
}
