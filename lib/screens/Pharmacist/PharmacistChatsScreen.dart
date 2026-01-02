import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../ChatScreen.dart';

class PharmacistChatsScreen extends StatelessWidget {
  const PharmacistChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Please login')));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('User Messages', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[200]),
                   const SizedBox(height: 16),
                   Text('No messages yet', style: GoogleFonts.inter(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final chatId = docs[index].id;
              final lastMsg = data['lastMessage'] ?? 'No messages yet';
              
              return FadeInUp(
                delay: Duration(milliseconds: 100 * index),
                child: Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[100]!),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE3F2FD),
                      child: Icon(Icons.person, color: Color(0xFF007BFF)),
                    ),
                    title: Text('Chat #$chatId', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      lastMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(chatId: chatId, title: 'User Chat'),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
