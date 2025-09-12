// This file explicitly registers Stimulus controllers
import { application } from "./application"
import NotificationController from "./notification_controller"

// Register the notification controller explicitly
application.register("notification", NotificationController)

// Log registered controllers for debugging
console.log("Registered Stimulus controllers:", application.controllers.map(c => c.identifier))
