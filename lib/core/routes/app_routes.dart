import 'package:get/get.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/pending_approval_screen.dart';

import '../../features/admin/screens/admin_dashboard.dart';
import '../../features/admin/screens/manage_users_screen.dart';
import '../../features/admin/screens/manage_service_types_screen.dart';
import '../../features/admin/screens/manage_task_types_screen.dart';
import '../../features/admin/screens/service_requests_screen.dart';
import '../../features/admin/screens/vehicles_screen.dart';
import '../../features/admin/screens/reports_screen.dart';

import '../../features/worker/screens/worker_dashboard.dart';
import '../../features/worker/screens/update_task_screen.dart';

import '../../features/donor/screens/donor_dashboard.dart';
import '../../features/donor/screens/donate_screen.dart';

import '../../features/beneficiary/screens/beneficiary_dashboard.dart';
import '../../features/beneficiary/screens/new_request_screen.dart';

import '../../features/guest/screens/guest_request_screen.dart';
import '../../features/chat/screens/chat_screen.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String pending = '/pending-approval';
  
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsers = '/admin/users';
  static const String adminServiceTypes = '/admin/service-types';
  static const String adminTaskTypes = '/admin/task-types';
  static const String adminRequests = '/admin/requests';
  static const String adminVehicles = '/admin/vehicles';
  static const String adminReports = '/admin/reports';

  static const String workerDashboard = '/worker/dashboard';
  static const String workerUpdateTask = '/worker/update';

  static const String donorDashboard = '/donor/dashboard';
  static const String donorDonate = '/donor/donate';

  static const String beneficiaryDashboard = '/beneficiary/dashboard';
  static const String beneficiaryNewRequest = '/beneficiary/new-request';

  static const String guestRequest = '/guest/request';
  static const String chat = '/chat';

  static List<GetPage> getPages() {
    return [
      GetPage(name: splash, page: () => const SplashScreen()),
      GetPage(name: login, page: () => const LoginScreen()),
      GetPage(name: register, page: () => const RegisterScreen()),
      GetPage(name: pending, page: () => const PendingApprovalScreen()),
      
      GetPage(name: adminDashboard, page: () => const AdminDashboard()),
      GetPage(name: adminUsers, page: () => const ManageUsersScreen()),
      GetPage(name: adminServiceTypes, page: () => const ManageServiceTypesScreen()),
      GetPage(name: adminTaskTypes, page: () => const ManageTaskTypesScreen()),
      GetPage(name: adminRequests, page: () => const ServiceRequestsScreen()),
      GetPage(name: adminVehicles, page: () => const VehiclesScreen()),
      GetPage(name: adminReports, page: () => const ReportsScreen()),
      
      GetPage(name: workerDashboard, page: () => const WorkerDashboard()),
      GetPage(name: workerUpdateTask, page: () => const UpdateTaskScreen()),
      GetPage(name: chat, page: () => const ChatScreen()),
      
      GetPage(name: donorDashboard, page: () => const DonorDashboard()),
      GetPage(name: donorDonate, page: () => const DonateScreen()),
      
      GetPage(name: beneficiaryDashboard, page: () => const BeneficiaryDashboard()),
      GetPage(name: beneficiaryNewRequest, page: () => const NewRequestScreen()),
      
      GetPage(name: guestRequest, page: () => const GuestRequestScreen()),
    ];
  }
}
