import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/chat_message_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/theme/app_theme.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final messageController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text("الدردشة العامة"),
        actions: [
          IconButton(
            icon: Icon(Get.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => AppConstants.toggleTheme(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(AppConstants.chatCollection)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                var messages = snapshot.data!.docs.map((doc) => ChatMessageModel.fromMap(doc.data() as Map<String, dynamic>)).toList();
                
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == authController.currentUser.value?.id;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? AppTheme.primaryGreen : Colors.grey[300],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isMe) Text(msg.senderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
                            Text(msg.message, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.image, color: Colors.grey), onPressed: () {}), // لإضافة صور لاحقاً
                Expanded(
                  child: TextField(
                    controller: messageController,
                    decoration: const InputDecoration(hintText: "اكتب رسالتك...", border: InputBorder.none),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppTheme.primaryGreen),
                  onPressed: () async {
                    if (messageController.text.trim().isEmpty) return;
                    final user = authController.currentUser.value!;
                    final msg = ChatMessageModel(
                      id: '',
                      senderId: user.id,
                      senderName: user.name,
                      message: messageController.text.trim(),
                      createdAt: DateTime.now(),
                    );
                    await FirebaseFirestore.instance.collection(AppConstants.chatCollection).add(msg.toMap());
                    messageController.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
