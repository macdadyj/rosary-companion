import Foundation

/// Stable names for the controls the UI tests tap. The iOS views use the same strings.
public enum UITag {
    public static let tabPray = "tab.pray"
    public static let tabToday = "tab.today"
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
    public static let modeRosary = "home.mode.rosary"
    public static let homeSearch = "home.search"
    public static let homeSearchClear = "home.search.clear"
    public static let homeFeast = "home.feast"
    public static let homeNovena = "home.novena"
    public static let homeFavorites = "home.favorites"
    public static let homeRecent = "home.recent"

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
    public static let devotionStep = "devotion.step"
    public static let devotionFullText = "devotion.fulltext"

    public static let litanyNext = "litany.next"
    public static let litanyBack = "litany.back"
    public static let litanyStep = "litany.step"
    public static let litanyFullText = "litany.fulltext"

    public static let librarySearch = "library.search"
    public static let libraryBody = "library.body"
    public static let libraryMemorare = "library.prayer.memorare"
    public static let libraryMichael = "library.prayer.st-michael-chaplet"
    public static let libraryOurLady = "library.category.ourLady"
    public static func libraryFavorite(_ id: String) -> String { "library.favorite.\(id)" }

    public static let readingsDay = "readings.day"
    public static let readingsBody = "readings.body"
    public static let readingsLink = "readings.link"
    public static let readingsColor = "readings.color"

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
    public static let settingsReadMeditation = "settings.readMeditation"
    public static let settingsReminder = "settings.reminder"
    public static let settingsResponsePause = "settings.responsePause"
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
    public static let sessionArtNext = "session.artNext"
    public static let sessionArtPrevious = "session.artPrevious"
    public static let sessionArtPage = "session.artPage"
    public static let sessionReadMeditation = "session.readMeditation"
    public static let sessionRate = "session.rate"
    public static let sessionScriptureReader = "session.scriptureReader"
    public static let sessionScriptureBody = "session.scriptureBody"
    public static let sessionScriptureClose = "session.scriptureClose"
    public static let sessionMysteryPrevious = "session.mystery.previous"
    public static let sessionMysteryNext = "session.mystery.next"
    public static func sessionMystery(_ number: Int) -> String { "session.mystery.\(number)" }

    public static let saintMystery = "saint.annunciation"
    public static let calendarToday = "calendar.today"

    public static let watchAdvance = "watch.advance"
    public static let watchBack = "watch.back"
    public static let watchReset = "watch.reset"
    public static let watchCount = "watch.count"

    public static let all = [
        tabPray, tabToday, tabDevotions, tabIntentions, tabSaints, tabSettings,
        beginRosary, offerIntentions, openCalendar, openJournal, openAngelus,
        modeGuided, modeTracking, modeRosary, homeSearch, homeSearchClear, homeFeast, homeNovena, homeFavorites, homeRecent,
        devotionSorrows, devotionMercy, devotionLitany, devotionHours,
        devotionConsecration, devotionCalendar, devotionJournal,
        devotionNext, devotionBack, devotionEnd, devotionStep, devotionFullText,
        litanyNext, litanyBack, litanyStep, litanyFullText,
        librarySearch, libraryBody, libraryMemorare, libraryMichael, libraryOurLady,
        libraryFavorite("memorare"),
        readingsDay, readingsBody, readingsLink, readingsColor,
        consecrationBegin, consecrationDay,
        intentionAdd, intentionField, intentionAnswered, intentionOngoing,
        settingsChant, settingsArt, settingsVoice, settingsHaptics, settingsHolyGhost,
        settingsSeasonal, settingsFamily, settingsMembers, settingsVoicePicker, settingsBuild,
        settingsRefreshArt, settingsReadMeditation, settingsReminder, settingsResponsePause,
        familyAdd, familyField,
        sessionEnd, sessionPause, sessionBack, sessionSurface,
        sessionBeads, sessionScripture, sessionArt, sessionPrayer, sessionRefreshArt,
        sessionArtFrame, sessionArtImage, sessionArtViewer, sessionArtClose, sessionArtCredit,
        sessionArtNext, sessionArtPrevious, sessionArtPage, sessionReadMeditation, sessionRate,
        sessionScriptureReader, sessionScriptureBody, sessionScriptureClose,
        sessionMysteryPrevious, sessionMysteryNext,
        sessionMystery(1), sessionMystery(2), sessionMystery(3), sessionMystery(4), sessionMystery(5),
        saintMystery, calendarToday,
        watchAdvance, watchBack, watchReset, watchCount,
    ]
}
