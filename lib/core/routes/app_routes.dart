import 'package:flutter/material.dart';
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
import '../../features/admin/screens/add_project_screen.dart';
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
import '../../features/chat/screens/chat_screen.dart';
import '../../features/shared/screens/profile_screen.dart';
import '../../data/models/service_request_model.dart';
import '../../data/models/project_model.dart';
import '../../data/models/user_model.dart';
import 'auth_middleware.dart';

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
  static const String adminAddProject = '/admin/add-project';
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
    
    // Admin Routes
    GetPage(name: adminDashboard, page: () => const AdminDashboard(), middlewares: [AuthMiddleware()]),
    GetPage(name: adminUsers, page: () => const ManageUsersScreen(), middlewares: [AuthMiddleware()]),
    GetPage(name: adminServiceTypes, page: () => const ManageServiceTypesScreen(), middlewares: [AuthMiddleware()]),
    GetPage(name: adminTaskTypes, page: () => const ManageTaskTypesScreen(), middlewares: [AuthMiddleware()]),
    GetPage(name: adminRequests, page: () => const ServiceRequestsScreen(), middlewares: [AuthMiddleware()]),
    GetPage(
      name: adminRequestDetail, 
      page: () {
        final req = Get.arguments;
        if (req is! ServiceRequestModel) return const Scaffold(body: Center(child: Text('خطأ في البيانات')));
        return RequestDetailScreen(request: req);
      },
      middlewares: [AuthMiddleware()]
    ),
    GetPage(name: adminProjects, page: () => ProjectsScreen(), middlewares: [AuthMiddleware()]),
    GetPage(
      name: adminProjectDetail, 
      page: () {
        final proj = Get.arguments;
        if (proj is! ProjectModel) return const Scaffold(body: Center(child: Text('خطأ في البيانات')));
        return ProjectDetailScreen(project: proj);
      },
      middlewares: [AuthMiddleware()]
    ),
    GetPage(name: adminAddProject, page: () => const AddProjectScreen(), middlewares: [AuthMiddleware()]),
    GetPage(name: adminWorkers, page: () => const WorkersScreen(), middlewares: [AuthMiddleware()]),
    GetPage(
      name: adminWorkerDetail, 
      page: () {
        final wk = Get.arguments;
        if (wk is! UserModel) return const Scaffold(body: Center(child: Text('خطأ في البيانات')));
        return WorkerDetailScreen(worker: wk);
      },
      middlewares: [AuthMiddleware()]
    ),
    GetPage(name: adminVehicles, page: () => const VehiclesScreen(), middlewares: [AuthMiddleware()]),
    GetPage(name: adminReports, page: () => const ReportsScreen(), middlewares: [AuthMiddleware()]),
    
    // Worker Routes
    GetPage(name: workerDashboard, page: () => const WorkerDashboard(), middlewares: [AuthMiddleware()]),
    GetPage(name: workerUpdateTask, page: () => const UpdateTaskScreen(), middlewares: [AuthMiddleware()]),
    
    // Donor Routes
    GetPage(name: donorDashboard, page: () => const DonorDashboard(), middlewares: [AuthMiddleware()]),
    GetPage(name: donorDonate, page: () => const DonateScreen(), middlewares: [AuthMiddleware()]),
    
    // Beneficiary Routes
    GetPage(name: beneficiaryDashboard, page: () => const BeneficiaryDashboard(), middlewares: [AuthMiddleware()]),
    GetPage(name: beneficiaryNewRequest, page: () => const NewRequestScreen(), middlewares: [AuthMiddleware()]),
    GetPage(
      name: beneficiaryRequestStatus, 
      page: () {
        final req = Get.arguments;
        if (req is! ServiceRequestModel) return const Scaffold(body: Center(child: Text('خطأ في البيانات')));
        return RequestStatusScreen(request: req);
      },
      middlewares: [AuthMiddleware()]
    ),
    
    // Guest Routes
    GetPage(name: guestRequest, page: () => const GuestRequestScreen()),
    GetPage(
      name: guestSuccess, 
      page: () {
        final args = Get.arguments as Map<String, dynamic>?;
        return GuestSuccessScreen(
          refNumber: args?['refNumber'] ?? '',
          phone: args?['phone'] ?? '',
        );
      }
    ),
    
    // Shared Routes
    GetPage(name: chat, page: () => const ChatScreen(), middlewares: [AuthMiddleware()]),
    GetPage(name: chatGroup, page: () => const ChatScreen(isGroupChat: true), middlewares: [AuthMiddleware()]),
    GetPage(
      name: chatPrivate, 
      page: () {
        final args = Get.arguments as Map<String, dynamic>?;
        return ChatScreen(
          isGroupChat: false, 
          targetUserId: args?['userId'] ?? '', 
          targetUserName: args?['userName'] ?? 'المحادثة'
        );
      },
      middlewares: [AuthMiddleware()]
    ),
    GetPage(name: notifications, page: () => const NotificationsScreen(), middlewares: [AuthMiddleware()]),
    GetPage(name: profile, page: () => const ProfileScreen(), middlewares: [AuthMiddleware()]),
  ];
}
