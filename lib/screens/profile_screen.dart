import 'package:flutter/material.dart';
import '../core/services/question_service.dart';
import '../core/theme/app_theme.dart';
import '../models/quiz_models.dart';
import '../widgets/buttons.dart';
import 'create_question_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final QuestionService _questionService = QuestionService();
  UserProfile? _userProfile;
  List<CreateQuestionModel> _userQuestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      print('DEBUG: Loading user data...');
      final profile = await _questionService.getUserProfile();
      print('DEBUG: Profile loaded: ${profile.displayName}, ${profile.email}');

      final questions = await _questionService.getUserQuestions();
      print('DEBUG: Questions loaded: ${questions.length} questions');

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _userQuestions = questions;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('DEBUG: Error loading profile: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Coba buat profile default jika belum ada
        if (e.toString().contains('tidak login')) {
          // User belum login, redirect ke auth
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Silakan login terlebih dahulu'),
              backgroundColor: Colors.orange,
            ),
          );
        } else {
          // Error lain, tampilkan pesan error tapi tetap coba buat fallback profile
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error memuat profile: $e'),
              backgroundColor: Colors.red,
            ),
          );

          // Set default profile untuk testing
          setState(() {
            _userProfile = UserProfile(
              uid: 'demo-user',
              displayName: 'Demo User',
              email: 'demo@example.com',
              createdAt: DateTime.now(),
              questionsCreated: 0,
              quizzesTaken: 0,
            );
            _userQuestions = [];
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userProfile == null
              ? const Center(child: Text('Gagal memuat profile'))
              : RefreshIndicator(
                  onRefresh: _loadUserData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileCard(),
                        const SizedBox(height: 20),
                        _buildStatsCard(),
                        const SizedBox(height: 20),
                        _buildCreateQuestionSection(),
                        const SizedBox(height: 20),
                        _buildMyQuestionsSection(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: _userProfile?.photoURL != null
                  ? NetworkImage(_userProfile!.photoURL!)
                  : null,
              child: _userProfile?.photoURL == null
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              _userProfile?.displayName ?? 'Unknown User',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _userProfile?.email ?? '',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bergabung sejak ${_formatDate(_userProfile?.createdAt)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              'Soal Dibuat',
              '${_userProfile?.questionsCreated ?? 0}',
              Icons.quiz,
              AppTheme.primaryColor,
            ),
            Container(
              height: 50,
              width: 1,
              color: Colors.grey[300],
            ),
            _buildStatItem(
              'Kuis Diambil',
              '${_userProfile?.quizzesTaken ?? 0}',
              Icons.assignment_turned_in,
              AppTheme.secondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildCreateQuestionSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Buat Soal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Buat soal sendiri dan bagikan kepada teman-teman untuk dimainkan!',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                text: 'Buat Soal Baru',
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateQuestionScreen(),
                    ),
                  );

                  if (result == true) {
                    _loadUserData(); // Refresh data
                  }
                },
                backgroundColor: AppTheme.primaryColor,
                textColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyQuestionsSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Soal Saya',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_userQuestions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        size: 60,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Belum ada soal yang dibuat',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _userQuestions.length,
                itemBuilder: (context, index) {
                  final question = _userQuestions[index];
                  return _buildQuestionItem(question);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionItem(CreateQuestionModel question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${question.subject} - Kelas ${question.grade}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'QID: ${question.qid}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            question.question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.timer, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                '${question.timeSuggestionSec}s',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.star, size: 16, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                '${question.points} poin',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year}';
  }
}
