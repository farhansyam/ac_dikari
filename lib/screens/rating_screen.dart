import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

class RatingScreen extends StatefulWidget {
  final int orderId;
  final String technicianName;
  // Rating teknisi pasang (relokasi beda lokasi)
  final String? secondTechnicianName;
  final bool splitTechnician;

  const RatingScreen({
    Key? key,
    required this.orderId,
    required this.technicianName,
    this.secondTechnicianName,
    this.splitTechnician = false,
  }) : super(key: key);

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  // Rating teknisi pertama (bongkar / tunggal)
  int _rating = 0;
  final _reviewCtrl = TextEditingController();

  // Rating teknisi pasang (relokasi beda lokasi)
  int _secondRating = 0;
  final _secondReviewCtrl = TextEditingController();

  bool _submitting = false;

  bool get _hasSecondTech =>
      widget.splitTechnician &&
      widget.secondTechnicianName != null &&
      widget.secondTechnicianName!.isNotEmpty;

  @override
  void dispose() {
    _reviewCtrl.dispose();
    _secondReviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      _showSnackBar('Pilih rating untuk ${widget.technicianName}.');
      return;
    }
    if (_hasSecondTech && _secondRating == 0) {
      _showSnackBar('Pilih rating untuk ${widget.secondTechnicianName}.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final auth = context.read<AuthService>();
      final body = <String, dynamic>{
        'rating': _rating,
        'review': _reviewCtrl.text.trim(),
      };
      if (_hasSecondTech) {
        body['second_rating'] = _secondRating;
        body['second_review'] = _secondReviewCtrl.text.trim();
      }

      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}/orders/${widget.orderId}/rating'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer ${auth.token}',
        },
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.of(context).pop(true);
      } else {
        final data = jsonDecode(response.body);
        setState(() => _submitting = false);
        _showSnackBar(data['message'] ?? 'Gagal mengirim rating.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnackBar(e.toString());
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Sangat Buruk 😞';
      case 2:
        return 'Buruk 😕';
      case 3:
        return 'Cukup 😐';
      case 4:
        return 'Bagus 😊';
      case 5:
        return 'Sangat Bagus 🤩';
      default:
        return 'Pilih rating';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Beri Ulasan'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ─── Rating Teknisi Pertama ───────────────────────
            _buildRatingCard(
              techName: widget.technicianName,
              label: _hasSecondTech ? 'Teknisi Bongkar' : null,
              rating: _rating,
              reviewCtrl: _reviewCtrl,
              onRatingChanged: (v) => setState(() => _rating = v),
            ),

            // ─── Rating Teknisi Pasang (relokasi 2 teknisi) ───
            if (_hasSecondTech) ...[
              const SizedBox(height: 16),
              _buildRatingCard(
                techName: widget.secondTechnicianName!,
                label: 'Teknisi Pasang',
                rating: _secondRating,
                reviewCtrl: _secondReviewCtrl,
                onRatingChanged: (v) => setState(() => _secondRating = v),
              ),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Kirim Ulasan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Lewati',
                style: TextStyle(
                  color: AppTheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingCard({
    required String techName,
    String? label,
    required int rating,
    required TextEditingController reviewCtrl,
    required ValueChanged<int> onRatingChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (label != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                techName.isNotEmpty ? techName[0].toUpperCase() : 'T',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Bagaimana pelayanan teknisi?',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            techName,
            style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Bintang
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final star = i + 1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onRatingChanged(star),
                  child: Icon(
                    star <= rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 40,
                    color: star <= rating ? Colors.amber : Colors.grey.shade300,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _ratingLabel(rating),
              key: ValueKey(rating),
              style: TextStyle(
                color: rating > 0
                    ? AppTheme.primary
                    : AppTheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Review
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tulis Ulasan (opsional)',
              style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: reviewCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Ceritakan pengalaman kamu...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}
