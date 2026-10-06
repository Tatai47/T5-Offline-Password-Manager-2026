import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/models/password_model.dart';
import 'package:flutter_application_1/utils/url_helper.dart';

void main() {
  testWidgets('App renders login screen test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PasswordManagerApp());

    // Verify that the login screen title shows up
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  test('PasswordItemModel serializes and deserializes websiteUrl and customLogo', () {
    final original = PasswordItemModel(
      id: 42,
      userId: 1,
      title: 'Google Account',
      usernameOrEmail: 'john@google.com',
      password: 'mypassword123',
      category: 'Social',
      notes: 'Recovery phone set',
      websiteUrl: 'https://accounts.google.com',
      customLogo: 'base64EncodedLogoString==',
      createdAt: '2026-10-05T12:00:00Z',
    );

    final map = original.toMap();
    expect(map['website_url'], 'https://accounts.google.com');
    expect(map['custom_logo'], 'base64EncodedLogoString==');

    final restored = PasswordItemModel.fromMap(map);
    expect(restored.id, 42);
    expect(restored.websiteUrl, 'https://accounts.google.com');
    expect(restored.customLogo, 'base64EncodedLogoString==');
    expect(restored.title, 'Google Account');

    final copied = restored.copyWith(websiteUrl: 'https://google.com');
    expect(copied.websiteUrl, 'https://google.com');
    expect(copied.customLogo, 'base64EncodedLogoString==');
  });

  test('extractDomain and getFaviconUrl extract host and build correct favicon URL', () {
    expect(extractDomain('https://github.com/flutter/flutter'), 'github.com');
    expect(extractDomain('https://www.amazon.in/'), 'amazon.in');
    expect(extractDomain('netflix.com'), 'netflix.com');
    expect(extractDomain('http://accounts.google.com/signin'), 'accounts.google.com');
    expect(extractDomain(''), isNull);

    expect(
      getFaviconUrl('https://github.com'),
      'https://icon.horse/icon/github.com',
    );
    expect(
      getFaviconUrl('https://www.amazon.in/'),
      'https://icon.horse/icon/amazon.in',
    );
    expect(
      getBackupFaviconUrl('https://www.amazon.in/'),
      'https://favicone.com/amazon.in?s=128',
    );
    expect(getFaviconUrl(''), isNull);
    expect(getFaviconUrl(null), isNull);
  });
}
