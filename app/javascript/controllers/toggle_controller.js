# ============================================================================
# FILE: app/javascript/controllers/toggle_controller.js
# ============================================================================
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "button"]

  toggle() {
    this.contentTarget.classList.toggle("hidden")
  }
}