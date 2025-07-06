// CalendarSync+Exports.swift
// Export all public APIs for external use

@_exported import Foundation
@_exported import EventKit

// Re-export all public types
public typealias CalendarSyncType = CalendarSync
public typealias CalendarEventType = CalendarEvent
public typealias CalendarSyncConfigurationType = CalendarSyncConfiguration
public typealias SyncStatusType = SyncStatus
public typealias SyncStatisticsType = SyncStatistics
public typealias CalendarSyncErrorType = CalendarSyncError
public typealias UpdateTypeType = UpdateType

// Reminder sync types
public typealias ReminderSyncType = ReminderSync
public typealias ReminderEventType = ReminderEvent
public typealias ReminderSyncStatusType = ReminderSyncStatus
public typealias ReminderSyncStatisticsType = ReminderSyncStatistics
public typealias ReminderUpdateTypeType = ReminderUpdateType 