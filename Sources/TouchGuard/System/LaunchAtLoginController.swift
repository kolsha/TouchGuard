import ServiceManagement

enum LaunchAtLoginController {
    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp

        if enabled {
            switch service.status {
            case .enabled:
                return
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
            case .notFound, .notRegistered:
                try service.register()
            @unknown default:
                try service.register()
            }
        } else if service.status != .notRegistered {
            try service.unregister()
        }
    }
}
