import Foundation

/// Stable names for the controls the UI tests tap. The iOS views use the same strings.
public enum UITag {
    public static let tabPray = "tab.pray"
    public static let tabDevotions = "tab.devotions"
    public static let tabIntentions = "tab.intentions"
    public static let tabSaints = "tab.saints"
    public static let tabSettings = "tab.settings"

    public static let beginRosary = "begin.rosary"
    public static let offerIntentions = "home.offer"
    public static let openCalendar = "home.calendar"
    public static let openJournal = "home.journal"
    public static let openAngelus = "home.angelus"
    public static let modeGuided = "home.mode.guided"
    public static let modeTracking = "home.mode.tracking"

    public static let devotionSorrows = "devotion.sorrows"
    public static let devotionMercy = "devotion.mercy"
    public static let devotionLitany = "devotion.litany"
    public static let devotionHours = "devotion.hours"
    public static let devotionConsecration = "devotion.consecration"
    public static let devotionCalendar = "devotion.calendar"
    public static let devotionJournal = "devotion.journal"

    public static let devotionNext = "devotion.next"
    public static let devotionBack = "devotion.back"
    public static let devotionEnd = "devotion.end"

    public static let litanyNext = "litany.next"
    public static let litanyBack = "litany.back"

    public static let consecrationBegin = "consecration.begin"
    public static let consecrationDay = "consecration.day.1"

    public static let intentionAdd = "intention.add"
    public static let intentionField = "intention.field"
    public static let intentionAnswered = "intention.answered"
    public static let intentionOngoing = "intention.ongoing"

    public static let settingsChant = "settings.chant"
    public static let settingsArt = "settings.art"
    public static let settingsVoice = "settings.voice"
    public static let settingsHaptics = "settings.haptics"
    public static let settingsHolyGhost = "settings.holyGhost"
    public static let settingsSeasonal = "settings.seasonal"
    public static let settingsFamily = "settings.family"
    public static let settingsMembers = "settings.members"
    public static let settingsVoicePicker = "settings.voicePicker"
    public static let settingsBuild = "settings.build"
    public static let settingsRefreshArt = "settings.refreshArt"
    public static let familyAdd = "family.add"
    public static let familyField = "family.field"

    public static let sessionEnd = "session.end"
    public static let sessionPause = "session.pause"
    public static let sessionBack = "session.back"
    public static let sessionSurface = "session.surface"
    public static let sessionBeads = "session.beads"
    public static let sessionScripture = "session.scripture"
    public static let sessionArt = "session.art"
    public static let sessionPrayer = "session.prayer"
    public static let sessionRefreshArt = "session.refreshArt"
    public static let sessionArtFrame = "session.artFrame"
    public static let sessionArtImage = "session.artImage"
    public static let sessionArtViewer = "session.artViewer"
    public static let sessionArtClose = "session.artClose"
    public static let sessionArtCredit = "session.artCredit"
    public static let sessionScriptureReader = "session.scriptureReader"
    public static let sessionScriptureBody = "session.scriptureBody"
    public static let sessionScriptureClose = "session.scriptureClose"

    public static let saintMystery = "saint.annunciation"
    public static let calendarToday = "calendar.today"

    public static let watchAdvance = "watch.advance"
    public static let watchBack = "watch.back"
    public static let watchReset = "watch.reset"
    public static let watchCount = "watch.count"

    public static let all = [
        tabPray, tabDevotions, tabIntentions, tabSaints, tabSettings,
        beginRosary, offerIntentions, openCalendar, openJournal, openAngelus,
        modeGuided, modeTracking,
        devotionSorrows, devotionMercy, devotionLitany, devotionHours,
        devotionConsecration, devotionCalendar, devotionJournal,
        devotionNext, devotionBack, devotionEnd,
        litanyNext, litanyBack,
        consecrationBegin, consecrationDay,
        intentionAdd, intentionField, intentionAnswered, intentionOngoing,
        settingsChant, settingsArt, settingsVoice, settingsHaptics, settingsHolyGhost,
        settingsSeasonal, settingsFamily, settingsMembers, settingsVoicePicker, settingsBuild,
        settingsRefreshArt,
        familyAdd, familyField,
        sessionEnd, sessionPause, sessionBack, sessionSurface,
        sessionBeads, sessionScripture, sessionArt, sessionPrayer, sessionRefreshArt,
        sessionArtFrame, sessionArtImage, sessionArtViewer, sessionArtClose, sessionArtCredit,
        sessionScriptureReader, sessionScriptureBody, sessionScriptureClose,
        saintMystery, calendarToday,
        watchAdvance, watchBack, watchReset, watchCount,
    ]
}
