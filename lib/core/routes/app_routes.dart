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
import '../../features/admin/screens/request_detail_screen.dart';
import '../../features/admin/screens/projects_screen.dart';
import '../../features/admin/screens/project_detail_screen.dart';
import '../../features/admin/screens/workers_screen.dart';
import '../../features/admin/screens/worker_detail_screen.dart';
import '../../features/admin/screens/vehicles_screen.dart';
import '../../features/admin/screens/reports_screen.dart';
import '../../features/worker/screens/worker_dashboard.dart';
import '../../features/worker/screens/update_task_screen.dart';
import '../../features/donor/screens/donor_dashboard.dart';
import '../../features/donor/screens/donate_screen.dart';
import '../../features/beneficiary/screens/beneficiary_dashboard.dart';
import '../../features/beneficiary/screens/new_request_screen.dart';
import '../../features/beneficiary/screens/request_status_screen.dart';
import '../../features/guest/screens/guest_request_screen.dart';
import '../../features/guest/screens/guest_success_screen.dart';
import '../../features/shared/screens/notifications_screen.dart';
import '../../features/shared/screens/chat_screen.dart';
import '../../features/shared/screens/profile_screen.dart';
import '../../data/models/service_request_model.dart';
import '../../data/models/project_model.dart';
import '../../data/models/user_model.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String pending = '/pending';
  
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsers = '/admin/users';
  static const String adminServiceTypes = '/admin/service-types';
  static const String adminTaskTypes = '/admin/task-types';
  static const String adminRequests = '/admin/requests';
  static const String adminRequestDetail = '/admin/request-detail';
  static const String adminProjects = '/admin/projects';
  static const String adminProjectDetail = '/admin/project-detail';
  static const String adminWorkers = '/admin/workers';
  static const String adminWorkerDetail = '/admin/worker-detail';
  static const String adminVehicles = '/admin/vehicles';
  static const String adminReports = '/admin/reports';
  
  static const String workerDashboard = '/worker/dashboard';
  static const String workerUpdateTask = '/worker/update-task';
  
  static const String donorDashboard = '/donor/dashboard';
  static const String donorDonate = '/donor/donate';
  
  static const String beneficiaryDashboard = '/beneficiary/dashboard';
  static const String beneficiaryNewRequest = '/beneficiary/new-request';
  static const String beneficiaryRequestStatus = '/beneficiary/request-status';
  
  static const String guestRequest = '/guest/request';
  static const String guestSuccess = '/guest/success';
  
  static const String chat = '/chat';
  static const String chatGroup = '/chat/group';
  static const String chatPrivate = '/chat/private';
  static const String notifications = '/notifications';
  static const String profile = '/profile';

  static List<GetPage> getPages() => [
    GetPage(name: splash, page: () => const SplashScreen()),
    GetPage(name: login, page: () => const LoginScreen()),
    GetPage(name: register, page: () => const RegisterScreen()),
    GetPage(name: pending, page: () => const PendingApprovalScreen()),
    
    GetPage(name: adminDashboard, page: () => const AdminDashboard()),
    GetPage(name: adminUsers, page: () => const ManageUsersScreen()),
    GetPage(name: adminServiceTypes, page: () => const ManageServiceTypesScreen()),
    GetPage(name: adminTaskTypes, page: () => const ManageTaskTypesScreen()),
    GetPage(name: adminRequests, page: () => const ServiceRequestsScreen()),
    GetPage(
      name: adminRequestDetail, 
      page: () => RequestDetailScreen(request: Get.arguments as ServiceRequestModel)
    ),
    GetPage(name: adminProjects, page: () => ProjectsScreen()),
    GetPage(
      name: adminProjectDetail, 
      page: () => ProjectDetailScreen(project: Get.arguments as ProjectModel)
    ),
    GetPage(name: adminWorkers, page: () => const WorkersScreen()),
    GetPage(
      name: adminWorkerDetail, 
      page: () => WorkerDetailScreen(worker: Get.arguments as UserModel)
    ),
    GetPage(name: adminVehicles, page: () => const VehiclesScreen()),
    GetPage(name: adminReports, page: () => const ReportsScreen()),
    
    GetPage(name: workerDashboard, page: () => const WorkerDashboard()),
    GetPage(name: workerUpdateTask, page: () => const UpdateTaskScreen()),
    
    GetPage(name: donorDashboard, page: () => const DonorDashboard()),
    GetPage(name: donorDonate, page: () => const DonateScreen()),
    
    GetPage(name: beneficiaryDashboard, page: () => const BeneficiaryDashboard()),
    GetPage(name: beneficiaryNewRequest, page: () => const NewRequestScreen()),
    GetPage(
      name: beneficiaryRequestStatus, 
      page: () => RequestStatusScreen(request: Get.arguments as ServiceRequestModel)
    ),
    
    GetPage(name: guestRequest, page: () => const GuestRequestScreen()),
    GetPage(
      name: guestSuccess, 
      page: () => GuestSuccessScreen(
        refNumber: Get.arguments['refNumber'],
        phone: Get.arguments['phone'],
      )
    ),
    
    GetPage(name: chat, page: () => const ChatScreen()),
    GetPage(name: chatGroup, page: () => const ChatScreen(isGroupChat: true)),
    GetPage(
      name: chatPrivate, 
      page: () => ChatScreen(
        isGroupChat: false, 
        targetUserId: Get.arguments['userId'], 
        targetUserName: Get.arguments['userName']
      )
    ),
    GetPage(name: notifications, page: () => const NotificationsScreen()),
    GetPage(name: profile, page: () => const ProfileScreen()),
  ];
}
