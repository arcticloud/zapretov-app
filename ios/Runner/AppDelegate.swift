import UIKit
import Flutter
import HiddifyCore
import Sentry
@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        setupFileManager()
        registerHandlers()
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func setupFileManager() {
        do {
            try FileManager.default.createDirectory(at: FilePath.workingDirectory, withIntermediateDirectories: true)
        } catch {
            NSLog("Zapretov: Failed to create working directory: \(error)")
        }
        FileManager.default.changeCurrentDirectoryPath(FilePath.sharedDirectory.path)
    }

    func registerHandlers() {
        if let r = self.registrar(forPlugin: MethodHandler.name) {
            MethodHandler.register(with: r)
        }
        if let r = self.registrar(forPlugin: PlatformMethodHandler.name) {
            PlatformMethodHandler.register(with: r)
        }
        if let r = self.registrar(forPlugin: FileMethodHandler.name) {
            FileMethodHandler.register(with: r)
        }
        if let r = self.registrar(forPlugin: StatusEventHandler.name) {
            StatusEventHandler.register(with: r)
        }
        if let r = self.registrar(forPlugin: AlertsEventHandler.name) {
            AlertsEventHandler.register(with: r)
        }
    }
}
