// MVVM: Service — external API wrapper only
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';

class DynamicLinkService {
  static const String _host = 'app.ratebridge.pk';

  Future<String> generateInviteLink(String token) async {
    try {
      final DynamicLinkParameters params = DynamicLinkParameters(
        uriPrefix: 'https://ratebridge.page.link',
        link: Uri.parse('https://$_host/invite/$token'),
        androidParameters: const AndroidParameters(
          packageName: 'pk.ratebridge.app',
          minimumVersion: 1,
        ),
        socialMetaTagParameters: SocialMetaTagParameters(
          title: 'RateBridge Supplier Invitation',
          description: 'You have been invited to supply materials on RateBridge',
        ),
      );
      final ShortDynamicLink shortLink =
        await FirebaseDynamicLinks.instance.buildShortLink(params);
      return shortLink.shortUrl.toString();
    } catch(e) {
      // Fallback to manual deep link
      return 'https://ratebridge.page.link/invite?token=$token';
    }
  }

  Future<String?> handleIncomingLink() async {
    // Check if app was opened from a dynamic link
    final PendingDynamicLinkData? initialLink =
      await FirebaseDynamicLinks.instance.getInitialLink();
    if (initialLink != null) {
      return _extractToken(initialLink.link);
    }

    // Listen for dynamic links while app is running
    FirebaseDynamicLinks.instance.onLink.listen((dynamicLinkData) {
      final token = _extractToken(dynamicLinkData.link);
      if (token != null) {
        // Navigate to invite landing — usually handled via go_router or a listener
      }
    });
    return null;
  }

  String? _extractToken(Uri link) {
    // Extract token from path: /invite/{token}
    final pathSegments = link.pathSegments;
    final inviteIndex = pathSegments.indexOf('invite');
    if (inviteIndex >= 0 && inviteIndex + 1 < pathSegments.length) {
      return pathSegments[inviteIndex + 1];
    }
    // Also check query param
    return link.queryParameters['token'];
  }
}
