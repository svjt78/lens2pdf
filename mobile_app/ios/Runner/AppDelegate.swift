import Flutter
import UIKit
import MessageUI

@main
@objc class AppDelegate: FlutterAppDelegate, MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: "share_targets", binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: FlutterResult) in
      guard let self = self else { result(FlutterError(code: "UNAVAILABLE", message: "no self", details: nil)); return }
      guard let args = call.arguments as? [String: Any], let path = args["path"] as? String else {
        result(FlutterError(code: "BAD_ARGS", message: "missing path", details: nil)); return
      }
      let url = URL(fileURLWithPath: path)
      switch call.method {
      case "email":
        let subject = (args["subject"] as? String) ?? "My Scan"
        let body = (args["body"] as? String) ?? ""
        self.shareEmail(url: url, subject: subject, body: body, result: result)
      case "sms":
        let body = (args["body"] as? String) ?? ""
        self.shareSms(url: url, body: body, result: result)
      case "whatsapp":
        self.shareWhatsApp(url: url, result: result)
      case "airdrop":
        self.shareAirdrop(url: url, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func present(_ vc: UIViewController) {
    window?.rootViewController?.present(vc, animated: true, completion: nil)
  }

  // MARK: - Email
  private func shareEmail(url: URL, subject: String, body: String, result: FlutterResult) {
    if MFMailComposeViewController.canSendMail() {
      let mail = MFMailComposeViewController()
      mail.mailComposeDelegate = self
      mail.setSubject(subject)
      mail.setMessageBody(body, isHTML: false)
      if let data = try? Data(contentsOf: url) {
        mail.addAttachmentData(data, mimeType: "application/pdf", fileName: url.lastPathComponent)
      }
      present(mail)
      result(nil)
    } else {
      // Fallback to activity view limited to Mail
      let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
      present(av)
      result(nil)
    }
  }

  // MARK: - SMS / iMessage
  private func shareSms(url: URL, body: String, result: FlutterResult) {
    if MFMessageComposeViewController.canSendText() {
      let sms = MFMessageComposeViewController()
      sms.messageComposeDelegate = self
      sms.body = body
      if MFMessageComposeViewController.canSendAttachments() {
        sms.addAttachmentURL(url, withAlternateFilename: url.lastPathComponent)
      }
      present(sms)
      result(nil)
    } else {
      let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
      present(av)
      result(nil)
    }
  }

  // MARK: - WhatsApp (best-effort via ActivityViewController)
  private func shareWhatsApp(url: URL, result: FlutterResult) {
    let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    present(av)
    result(nil)
  }

  // MARK: - AirDrop only
  private func shareAirdrop(url: URL, result: FlutterResult) {
    let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    if #available(iOS 13.0, *) {
      av.excludedActivityTypes = [.addToReadingList, .assignToContact, .copyToPasteboard, .markupAsPDF, .openInIBooks, .postToFacebook, .postToFlickr, .postToTencentWeibo, .postToTwitter, .postToVimeo, .postToWeibo, .print, .saveToCameraRoll, .message, .mail]
    }
    present(av)
    result(nil)
  }

  // MARK: - Delegates
  func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
    controller.dismiss(animated: true, completion: nil)
  }

  func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
    controller.dismiss(animated: true, completion: nil)
  }
}
