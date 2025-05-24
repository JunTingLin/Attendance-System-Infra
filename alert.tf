resource "google_monitoring_notification_channel" "email" {
  display_name = "林俊霆"
  type         = "email"
  labels = {
    email_address = "junting0218@gmail.com"
  }
}

resource "google_monitoring_notification_channel" "email_jen" {
  display_name = "蔡甄芳"
  type         = "email"
  labels = {
    email_address = "jen.futurenest@gmail.com"
  }
}

resource "google_monitoring_notification_channel" "email_r13725005" {
  display_name = "呂蓁蓁"
  type         = "email"
  labels = {
    email_address = "r13725005@g.ntu.edu.tw"
  }
}
resource "google_monitoring_notification_channel" "email_songchiu" {
  display_name = "顧明祐"
  type         = "email"
  labels = {
    email_address = "songchiu.tw@gmail.com"
  }
}

# Front-end Uptime Check
resource "google_monitoring_uptime_check_config" "frontend" {
  display_name = "Front-end Uptime Check"
  project      = "tsmc-attendance-system-458811"

  # HTTP check settings
  http_check {
    path    = "/"
    port    = 443
    use_ssl = true
  }

  # Monitored resource must be uptime_url
  monitored_resource {
    type = "uptime_url"
    labels = {
      host = "tsmc-attendance-system.junting.info"
    }
  }

  timeout = "10s"   # wait up to 10s for a response
  period  = "60s"   # check every 60s
}

# Back-end Uptime Check
resource "google_monitoring_uptime_check_config" "backend" {
  display_name = "Back-end Uptime Check"
  project      = "tsmc-attendance-system-458811"

  http_check {
    path    = "/swagger-ui/index.html"
    port    = 443
    use_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      host = "attendance-system-api-752674193588.asia-east1.run.app"
    }
  }

  timeout = "10s"
  period  = "60s"
}

# Front-end Alert Policy
resource "google_monitoring_alert_policy" "frontend_down" {
  display_name          = "Front-end Down Alert"
  project               = "tsmc-attendance-system-458811"
  combiner              = "OR"
  notification_channels = [ 
    google_monitoring_notification_channel.email.id,
    google_monitoring_notification_channel.email_jen.id,
    google_monitoring_notification_channel.email_r13725005.id,
    google_monitoring_notification_channel.email_songchiu.id
    ]

  conditions {
    display_name = "Front-end Unreachable"
    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\" AND resource.label.\"host\"=\"tsmc-attendance-system.junting.info\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1              # Less than 100% uptime
      duration        = "60s"          # sustained for 60s
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_FRACTION_TRUE"
      }
    }
  }
}

# Back-end Alert Policy
resource "google_monitoring_alert_policy" "backend_down" {
  display_name          = "Back-end Down Alert"
  project               = "tsmc-attendance-system-458811"
  combiner              = "OR"
  notification_channels = [ 
    google_monitoring_notification_channel.email.id,
    google_monitoring_notification_channel.email_jen.id,
    google_monitoring_notification_channel.email_r13725005.id,
    google_monitoring_notification_channel.email_songchiu.id
    ]

  conditions {
    display_name = "Back-end Unreachable"
    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\" AND resource.label.\"host\"=\"attendance-system-api-752674193588.asia-east1.run.app\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1              # Less than 100% uptime
      duration        = "60s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_FRACTION_TRUE"
      }
    }
  }
}
