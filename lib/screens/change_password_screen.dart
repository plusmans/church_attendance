import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChangePasswordScreen extends StatefulWidget {
  final User user;
  final String docId;
  final bool isMandatory; // true면 첫 로그인 강제 변경 모드

  const ChangePasswordScreen({
    super.key,
    required this.user,
    required this.docId,
    this.isMandatory = false,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPwController = TextEditingController();
  final _pwController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _isOldPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  Future<void> _updatePassword() async {
    final oldPassword = _oldPwController.text.trim();
    final password = _pwController.text.trim();
    final confirm = _confirmController.text.trim();

    if (oldPassword.isEmpty) {
      _showMsg('현재 비밀번호를 입력해주세요.');
      return;
    }
    if (password.length < 6) {
      _showMsg('새 비밀번호는 최소 6자리 이상이어야 합니다.');
      return;
    }

    if (oldPassword == password) {
      _showMsg('새 비밀번호는 현재 비밀번호와 다르게 설정해야 합니다.');
      return;
    }

    if (password != confirm) {
      _showMsg('새 비밀번호 확인이 일치하지 않습니다.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      AuthCredential credential = EmailAuthProvider.credential(
        email: widget.user.email!,
        password: oldPassword,
      );
      await widget.user.reauthenticateWithCredential(credential);
      await widget.user.updatePassword(password);

      if (widget.isMandatory) {
        await FirebaseFirestore.instance
            .collection('teachers')
            .doc(widget.docId)
            .update({'isFirstLogin': false});
      }

      if (!mounted) return;
      _showMsg('비밀번호가 성공적으로 변경되었습니다!');

      if (!widget.isMandatory) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _showMsg('현재 비밀번호가 일치하지 않습니다.');
      } else if (e.code == 'requires-recent-login') {
        _showMsg('보안을 위해 다시 로그인 후 변경해주세요.');
        await FirebaseAuth.instance.signOut();
      } else {
        _showMsg('오류: ${e.message}');
      }
    } catch (e) {
      _showMsg('오류가 발생했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: widget.isMandatory
          ? null
          : AppBar(
              title: const Text(
                '비밀번호 변경',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.black87,
            ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 상단 아이콘 (크기 축소)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_open_rounded,
                    size: 48,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.isMandatory ? '첫 로그인을 환영합니다!' : '비밀번호 변경',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isMandatory
                      ? '보안을 위해 비밀번호를 변경해주세요.'
                      : '새로운 비밀번호를 설정합니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
                const SizedBox(height: 24),

                // 입력 카드 섹션 (너비 및 패딩 축소)
                Container(
                  width: size.width * 0.85, // 전체적인 테이블 크기(너비) 축소
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildPasswordField(
                        controller: _oldPwController,
                        label: '현재 비밀번호',
                        hint: '기존 비밀번호',
                        isVisible: _isOldPasswordVisible,
                        onToggle: () => setState(
                          () => _isOldPasswordVisible = !_isOldPasswordVisible,
                        ),
                      ),
                      const SizedBox(height: 12), // 간격 축소
                      const Divider(color: Color(0xFFF1F3F4), height: 1),
                      const SizedBox(height: 12), // 간격 축소
                      _buildPasswordField(
                        controller: _pwController,
                        label: '새 비밀번호',
                        hint: '6자리 이상',
                        isVisible: _isNewPasswordVisible,
                        onToggle: () => setState(
                          () => _isNewPasswordVisible = !_isNewPasswordVisible,
                        ),
                      ),
                      const SizedBox(height: 10), // 필드 간 간격 축소
                      _buildPasswordField(
                        controller: _confirmController,
                        label: '새 비밀번호 확인',
                        hint: '한 번 더 입력',
                        isVisible: _isConfirmPasswordVisible,
                        onToggle: () => setState(
                          () => _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 실행 버튼 (크기 축소)
                SizedBox(
                  width: size.width * 0.55, // 너비 축소
                  height: 44, // 높이 축소
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updatePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '변경 완료',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    if (widget.isMandatory) {
                      FirebaseAuth.instance.signOut();
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(
                    widget.isMandatory ? '로그아웃' : '나중에 하기',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isVisible,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: !isVisible,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 13),
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: Colors.teal,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isVisible
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 16,
                color: Colors.grey.shade400,
              ),
              onPressed: onToggle,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            filled: true,
            fillColor: const Color(0xFFFBFCFD),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade50),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.teal, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}
