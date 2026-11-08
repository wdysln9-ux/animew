// Hero header: backdrop, poster, trailer playback and the action buttons.
part of 'detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Hero — full-width backdrop with a portrait poster overlapping the bottom-right
// and a back arrow over the top-left.
// ─────────────────────────────────────────────────────────────────────────────

// Primary action controls used by the rebuilt detail layout.

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.label,
    this.onPressed,
    this.icon = Icons.play_arrow_rounded,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled || loading ? 1.0 : 0.4,
      child: Material(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onPressed,
          child: Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.textPrimary, size: 24),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.button.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-width GRAY Download button (surface2, white label) — Netflix-style.
// Downloads aren't implemented yet, so it just snacks.
// ─────────────────────────────────────────────────────────────────────────────

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon = Icons.file_download_outlined,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed != null || loading ? 1.0 : 0.4,
      child: Material(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onPressed,
          child: Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.textPrimary, size: 23),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.button.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
