import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../../../core/components/index.dart";
import "../../../../core/network/api_client.dart";
import "../../../../core/theme/design_tokens.dart";

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<ApiClient>();
      final response = await apiClient.get("/passenger/notifications");
      final data = response["data"] as List?;
      setState(() {
        _notifications = (data ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (e) {
      setState(() {
        _error = "Failed to load notifications.";
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: Container(
        color: DesignTokens.bg,
        child: RefreshIndicator(
          onRefresh: _load,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        Center(child: Text(_error!)),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton(
                              onPressed: _load, child: const Text("Retry")),
                        ),
                      ],
                    )
                  : _notifications.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            SizedBox(height: 80),
                            Icon(Icons.notifications_none_rounded,
                                size: 48, color: DesignTokens.muted),
                            SizedBox(height: 16),
                            Center(child: Text("No notifications yet")),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(DesignTokens.spacing16),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: DesignTokens.spacing8),
                          itemBuilder: (context, index) {
                            final n = _notifications[index];
                            final isRead =
                                n["is_read"] == 1 || n["is_read"] == true;
                            return AppCard(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    isRead
                                        ? Icons.notifications_none_rounded
                                        : Icons.notifications_active_rounded,
                                    color: isRead
                                        ? DesignTokens.muted
                                        : DesignTokens.accent,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (n["title"] as String?) ??
                                              "Notification",
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: DesignTokens.text,
                                              ),
                                        ),
                                        if (n["body"] != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            n["body"].toString(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}
