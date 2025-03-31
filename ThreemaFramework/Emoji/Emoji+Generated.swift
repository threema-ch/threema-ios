//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2025 Threema GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License, version 3,
// as published by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

import Foundation

// swiftformat:disable all

public enum Emoji: String, Identifiable, Hashable, CaseIterable {
    case grinningFace = "😀"
    case grinningFaceWithBigEyes = "😃"
    case grinningFaceWithSmilingEyes = "😄"
    case beamingFaceWithSmilingEyes = "😁"
    case grinningSquintingFace = "😆"
    case grinningFaceWithSweat = "😅"
    case rollingOnTheFloorLaughing = "🤣"
    case faceWithTearsOfJoy = "😂"
    case slightlySmilingFace = "🙂"
    case upsideDownFace = "🙃"
    case meltingFace = "🫠"
    case winkingFace = "😉"
    case smilingFaceWithSmilingEyes = "😊"
    case smilingFaceWithHalo = "😇"
    case smilingFaceWithHearts = "🥰"
    case smilingFaceWithHeartEyes = "😍"
    case starStruck = "🤩"
    case faceBlowingAKiss = "😘"
    case kissingFace = "😗"
    case smilingFace = "☺️"
    case kissingFaceWithClosedEyes = "😚"
    case kissingFaceWithSmilingEyes = "😙"
    case smilingFaceWithTear = "🥲"
    case faceSavoringFood = "😋"
    case faceWithTongue = "😛"
    case winkingFaceWithTongue = "😜"
    case zanyFace = "🤪"
    case squintingFaceWithTongue = "😝"
    case moneyMouthFace = "🤑"
    case smilingFaceWithOpenHands = "🤗"
    case faceWithHandOverMouth = "🤭"
    case faceWithOpenEyesAndHandOverMouth = "🫢"
    case faceWithPeekingEye = "🫣"
    case shushingFace = "🤫"
    case thinkingFace = "🤔"
    case salutingFace = "🫡"
    case zipperMouthFace = "🤐"
    case faceWithRaisedEyebrow = "🤨"
    case neutralFace = "😐"
    case expressionlessFace = "😑"
    case faceWithoutMouth = "😶"
    case dottedLineFace = "🫥"
    case faceInClouds = "😶‍🌫️"
    case smirkingFace = "😏"
    case unamusedFace = "😒"
    case faceWithRollingEyes = "🙄"
    case grimacingFace = "😬"
    case faceExhaling = "😮‍💨"
    case lyingFace = "🤥"
    case shakingFace = "🫨"
    case headShakingHorizontally = "🙂‍↔️"
    case headShakingVertically = "🙂‍↕️"
    case relievedFace = "😌"
    case pensiveFace = "😔"
    case sleepyFace = "😪"
    case droolingFace = "🤤"
    case sleepingFace = "😴"
    case faceWithBagsUnderEyes = "🫩"
    case faceWithMedicalMask = "😷"
    case faceWithThermometer = "🤒"
    case faceWithHeadBandage = "🤕"
    case nauseatedFace = "🤢"
    case faceVomiting = "🤮"
    case sneezingFace = "🤧"
    case hotFace = "🥵"
    case coldFace = "🥶"
    case woozyFace = "🥴"
    case faceWithCrossedOutEyes = "😵"
    case faceWithSpiralEyes = "😵‍💫"
    case explodingHead = "🤯"
    case cowboyHatFace = "🤠"
    case partyingFace = "🥳"
    case disguisedFace = "🥸"
    case smilingFaceWithSunglasses = "😎"
    case nerdFace = "🤓"
    case faceWithMonocle = "🧐"
    case confusedFace = "😕"
    case faceWithDiagonalMouth = "🫤"
    case worriedFace = "😟"
    case slightlyFrowningFace = "🙁"
    case frowningFace = "☹️"
    case faceWithOpenMouth = "😮"
    case hushedFace = "😯"
    case astonishedFace = "😲"
    case flushedFace = "😳"
    case pleadingFace = "🥺"
    case faceHoldingBackTears = "🥹"
    case frowningFaceWithOpenMouth = "😦"
    case anguishedFace = "😧"
    case fearfulFace = "😨"
    case anxiousFaceWithSweat = "😰"
    case sadButRelievedFace = "😥"
    case cryingFace = "😢"
    case loudlyCryingFace = "😭"
    case faceScreamingInFear = "😱"
    case confoundedFace = "😖"
    case perseveringFace = "😣"
    case disappointedFace = "😞"
    case downcastFaceWithSweat = "😓"
    case wearyFace = "😩"
    case tiredFace = "😫"
    case yawningFace = "🥱"
    case faceWithSteamFromNose = "😤"
    case enragedFace = "😡"
    case angryFace = "😠"
    case faceWithSymbolsOnMouth = "🤬"
    case smilingFaceWithHorns = "😈"
    case angryFaceWithHorns = "👿"
    case skull = "💀"
    case skullAndCrossbones = "☠️"
    case pileOfPoo = "💩"
    case clownFace = "🤡"
    case ogre = "👹"
    case goblin = "👺"
    case ghost = "👻"
    case alien = "👽"
    case alienMonster = "👾"
    case robot = "🤖"
    case grinningCat = "😺"
    case grinningCatWithSmilingEyes = "😸"
    case catWithTearsOfJoy = "😹"
    case smilingCatWithHeartEyes = "😻"
    case catWithWrySmile = "😼"
    case kissingCat = "😽"
    case wearyCat = "🙀"
    case cryingCat = "😿"
    case poutingCat = "😾"
    case seeNoEvilMonkey = "🙈"
    case hearNoEvilMonkey = "🙉"
    case speakNoEvilMonkey = "🙊"
    case loveLetter = "💌"
    case heartWithArrow = "💘"
    case heartWithRibbon = "💝"
    case sparklingHeart = "💖"
    case growingHeart = "💗"
    case beatingHeart = "💓"
    case revolvingHearts = "💞"
    case twoHearts = "💕"
    case heartDecoration = "💟"
    case heartExclamation = "❣️"
    case brokenHeart = "💔"
    case heartOnFire = "❤️‍🔥"
    case mendingHeart = "❤️‍🩹"
    case redHeart = "❤️"
    case pinkHeart = "🩷"
    case orangeHeart = "🧡"
    case yellowHeart = "💛"
    case greenHeart = "💚"
    case blueHeart = "💙"
    case lightBlueHeart = "🩵"
    case purpleHeart = "💜"
    case brownHeart = "🤎"
    case blackHeart = "🖤"
    case greyHeart = "🩶"
    case whiteHeart = "🤍"
    case kissMark = "💋"
    case hundredPoints = "💯"
    case angerSymbol = "💢"
    case collision = "💥"
    case dizzy = "💫"
    case sweatDroplets = "💦"
    case dashingAway = "💨"
    case hole = "🕳️"
    case speechBalloon = "💬"
    case eyeInSpeechBubble = "👁️‍🗨️"
    case leftSpeechBubble = "🗨️"
    case rightAngerBubble = "🗯️"
    case thoughtBalloon = "💭"
    case zzz = "💤"
    case wavingHand = "👋"
    case raisedBackOfHand = "🤚"
    case handWithFingersSplayed = "🖐️"
    case raisedHand = "✋"
    case vulcanSalute = "🖖"
    case rightwardsHand = "🫱"
    case leftwardsHand = "🫲"
    case palmDownHand = "🫳"
    case palmUpHand = "🫴"
    case leftwardsPushingHand = "🫷"
    case rightwardsPushingHand = "🫸"
    case okHand = "👌"
    case pinchedFingers = "🤌"
    case pinchingHand = "🤏"
    case victoryHand = "✌️"
    case crossedFingers = "🤞"
    case handWithIndexFingerAndThumbCrossed = "🫰"
    case loveYouGesture = "🤟"
    case signOfTheHorns = "🤘"
    case callMeHand = "🤙"
    case backhandIndexPointingLeft = "👈"
    case backhandIndexPointingRight = "👉"
    case backhandIndexPointingUp = "👆"
    case middleFinger = "🖕"
    case backhandIndexPointingDown = "👇"
    case indexPointingUp = "☝️"
    case indexPointingAtTheViewer = "🫵"
    case thumbsUp = "👍"
    case thumbsDown = "👎"
    case raisedFist = "✊"
    case oncomingFist = "👊"
    case leftFacingFist = "🤛"
    case rightFacingFist = "🤜"
    case clappingHands = "👏"
    case raisingHands = "🙌"
    case heartHands = "🫶"
    case openHands = "👐"
    case palmsUpTogether = "🤲"
    case handshake = "🤝"
    case foldedHands = "🙏"
    case writingHand = "✍️"
    case nailPolish = "💅"
    case selfie = "🤳"
    case flexedBiceps = "💪"
    case mechanicalArm = "🦾"
    case mechanicalLeg = "🦿"
    case leg = "🦵"
    case foot = "🦶"
    case ear = "👂"
    case earWithHearingAid = "🦻"
    case nose = "👃"
    case brain = "🧠"
    case anatomicalHeart = "🫀"
    case lungs = "🫁"
    case tooth = "🦷"
    case bone = "🦴"
    case eyes = "👀"
    case eye = "👁️"
    case tongue = "👅"
    case mouth = "👄"
    case bitingLip = "🫦"
    case baby = "👶"
    case child = "🧒"
    case boy = "👦"
    case girl = "👧"
    case person = "🧑"
    case personBlondHair = "👱"
    case man = "👨"
    case personBeard = "🧔"
    case manBeard = "🧔‍♂️"
    case womanBeard = "🧔‍♀️"
    case manRedHair = "👨‍🦰"
    case manCurlyHair = "👨‍🦱"
    case manWhiteHair = "👨‍🦳"
    case manBald = "👨‍🦲"
    case woman = "👩"
    case womanRedHair = "👩‍🦰"
    case personRedHair = "🧑‍🦰"
    case womanCurlyHair = "👩‍🦱"
    case personCurlyHair = "🧑‍🦱"
    case womanWhiteHair = "👩‍🦳"
    case personWhiteHair = "🧑‍🦳"
    case womanBald = "👩‍🦲"
    case personBald = "🧑‍🦲"
    case womanBlondHair = "👱‍♀️"
    case manBlondHair = "👱‍♂️"
    case olderPerson = "🧓"
    case oldMan = "👴"
    case oldWoman = "👵"
    case personFrowning = "🙍"
    case manFrowning = "🙍‍♂️"
    case womanFrowning = "🙍‍♀️"
    case personPouting = "🙎"
    case manPouting = "🙎‍♂️"
    case womanPouting = "🙎‍♀️"
    case personGesturingNo = "🙅"
    case manGesturingNo = "🙅‍♂️"
    case womanGesturingNo = "🙅‍♀️"
    case personGesturingOk = "🙆"
    case manGesturingOk = "🙆‍♂️"
    case womanGesturingOk = "🙆‍♀️"
    case personTippingHand = "💁"
    case manTippingHand = "💁‍♂️"
    case womanTippingHand = "💁‍♀️"
    case personRaisingHand = "🙋"
    case manRaisingHand = "🙋‍♂️"
    case womanRaisingHand = "🙋‍♀️"
    case deafPerson = "🧏"
    case deafMan = "🧏‍♂️"
    case deafWoman = "🧏‍♀️"
    case personBowing = "🙇"
    case manBowing = "🙇‍♂️"
    case womanBowing = "🙇‍♀️"
    case personFacepalming = "🤦"
    case manFacepalming = "🤦‍♂️"
    case womanFacepalming = "🤦‍♀️"
    case personShrugging = "🤷"
    case manShrugging = "🤷‍♂️"
    case womanShrugging = "🤷‍♀️"
    case healthWorker = "🧑‍⚕️"
    case manHealthWorker = "👨‍⚕️"
    case womanHealthWorker = "👩‍⚕️"
    case student = "🧑‍🎓"
    case manStudent = "👨‍🎓"
    case womanStudent = "👩‍🎓"
    case teacher = "🧑‍🏫"
    case manTeacher = "👨‍🏫"
    case womanTeacher = "👩‍🏫"
    case judge = "🧑‍⚖️"
    case manJudge = "👨‍⚖️"
    case womanJudge = "👩‍⚖️"
    case farmer = "🧑‍🌾"
    case manFarmer = "👨‍🌾"
    case womanFarmer = "👩‍🌾"
    case cook = "🧑‍🍳"
    case manCook = "👨‍🍳"
    case womanCook = "👩‍🍳"
    case mechanic = "🧑‍🔧"
    case manMechanic = "👨‍🔧"
    case womanMechanic = "👩‍🔧"
    case factoryWorker = "🧑‍🏭"
    case manFactoryWorker = "👨‍🏭"
    case womanFactoryWorker = "👩‍🏭"
    case officeWorker = "🧑‍💼"
    case manOfficeWorker = "👨‍💼"
    case womanOfficeWorker = "👩‍💼"
    case scientist = "🧑‍🔬"
    case manScientist = "👨‍🔬"
    case womanScientist = "👩‍🔬"
    case technologist = "🧑‍💻"
    case manTechnologist = "👨‍💻"
    case womanTechnologist = "👩‍💻"
    case singer = "🧑‍🎤"
    case manSinger = "👨‍🎤"
    case womanSinger = "👩‍🎤"
    case artist = "🧑‍🎨"
    case manArtist = "👨‍🎨"
    case womanArtist = "👩‍🎨"
    case pilot = "🧑‍✈️"
    case manPilot = "👨‍✈️"
    case womanPilot = "👩‍✈️"
    case astronaut = "🧑‍🚀"
    case manAstronaut = "👨‍🚀"
    case womanAstronaut = "👩‍🚀"
    case firefighter = "🧑‍🚒"
    case manFirefighter = "👨‍🚒"
    case womanFirefighter = "👩‍🚒"
    case policeOfficer = "👮"
    case manPoliceOfficer = "👮‍♂️"
    case womanPoliceOfficer = "👮‍♀️"
    case detective = "🕵️"
    case manDetective = "🕵️‍♂️"
    case womanDetective = "🕵️‍♀️"
    case personGuard = "💂"
    case manGuard = "💂‍♂️"
    case womanGuard = "💂‍♀️"
    case ninja = "🥷"
    case constructionWorker = "👷"
    case manConstructionWorker = "👷‍♂️"
    case womanConstructionWorker = "👷‍♀️"
    case personWithCrown = "🫅"
    case prince = "🤴"
    case princess = "👸"
    case personWearingTurban = "👳"
    case manWearingTurban = "👳‍♂️"
    case womanWearingTurban = "👳‍♀️"
    case personWithSkullcap = "👲"
    case womanWithHeadscarf = "🧕"
    case personInTuxedo = "🤵"
    case manInTuxedo = "🤵‍♂️"
    case womanInTuxedo = "🤵‍♀️"
    case personWithVeil = "👰"
    case manWithVeil = "👰‍♂️"
    case womanWithVeil = "👰‍♀️"
    case pregnantWoman = "🤰"
    case pregnantMan = "🫃"
    case pregnantPerson = "🫄"
    case breastFeeding = "🤱"
    case womanFeedingBaby = "👩‍🍼"
    case manFeedingBaby = "👨‍🍼"
    case personFeedingBaby = "🧑‍🍼"
    case babyAngel = "👼"
    case santaClaus = "🎅"
    case mrsClaus = "🤶"
    case mxClaus = "🧑‍🎄"
    case superhero = "🦸"
    case manSuperhero = "🦸‍♂️"
    case womanSuperhero = "🦸‍♀️"
    case supervillain = "🦹"
    case manSupervillain = "🦹‍♂️"
    case womanSupervillain = "🦹‍♀️"
    case mage = "🧙"
    case manMage = "🧙‍♂️"
    case womanMage = "🧙‍♀️"
    case fairy = "🧚"
    case manFairy = "🧚‍♂️"
    case womanFairy = "🧚‍♀️"
    case vampire = "🧛"
    case manVampire = "🧛‍♂️"
    case womanVampire = "🧛‍♀️"
    case merperson = "🧜"
    case merman = "🧜‍♂️"
    case mermaid = "🧜‍♀️"
    case elf = "🧝"
    case manElf = "🧝‍♂️"
    case womanElf = "🧝‍♀️"
    case genie = "🧞"
    case manGenie = "🧞‍♂️"
    case womanGenie = "🧞‍♀️"
    case zombie = "🧟"
    case manZombie = "🧟‍♂️"
    case womanZombie = "🧟‍♀️"
    case troll = "🧌"
    case personGettingMassage = "💆"
    case manGettingMassage = "💆‍♂️"
    case womanGettingMassage = "💆‍♀️"
    case personGettingHaircut = "💇"
    case manGettingHaircut = "💇‍♂️"
    case womanGettingHaircut = "💇‍♀️"
    case personWalking = "🚶"
    case manWalking = "🚶‍♂️"
    case womanWalking = "🚶‍♀️"
    case personWalkingFacingRight = "🚶‍➡️"
    case womanWalkingFacingRight = "🚶‍♀️‍➡️"
    case manWalkingFacingRight = "🚶‍♂️‍➡️"
    case personStanding = "🧍"
    case manStanding = "🧍‍♂️"
    case womanStanding = "🧍‍♀️"
    case personKneeling = "🧎"
    case manKneeling = "🧎‍♂️"
    case womanKneeling = "🧎‍♀️"
    case personKneelingFacingRight = "🧎‍➡️"
    case womanKneelingFacingRight = "🧎‍♀️‍➡️"
    case manKneelingFacingRight = "🧎‍♂️‍➡️"
    case personWithWhiteCane = "🧑‍🦯"
    case personWithWhiteCaneFacingRight = "🧑‍🦯‍➡️"
    case manWithWhiteCane = "👨‍🦯"
    case manWithWhiteCaneFacingRight = "👨‍🦯‍➡️"
    case womanWithWhiteCane = "👩‍🦯"
    case womanWithWhiteCaneFacingRight = "👩‍🦯‍➡️"
    case personInMotorizedWheelchair = "🧑‍🦼"
    case personInMotorizedWheelchairFacingRight = "🧑‍🦼‍➡️"
    case manInMotorizedWheelchair = "👨‍🦼"
    case manInMotorizedWheelchairFacingRight = "👨‍🦼‍➡️"
    case womanInMotorizedWheelchair = "👩‍🦼"
    case womanInMotorizedWheelchairFacingRight = "👩‍🦼‍➡️"
    case personInManualWheelchair = "🧑‍🦽"
    case personInManualWheelchairFacingRight = "🧑‍🦽‍➡️"
    case manInManualWheelchair = "👨‍🦽"
    case manInManualWheelchairFacingRight = "👨‍🦽‍➡️"
    case womanInManualWheelchair = "👩‍🦽"
    case womanInManualWheelchairFacingRight = "👩‍🦽‍➡️"
    case personRunning = "🏃"
    case manRunning = "🏃‍♂️"
    case womanRunning = "🏃‍♀️"
    case personRunningFacingRight = "🏃‍➡️"
    case womanRunningFacingRight = "🏃‍♀️‍➡️"
    case manRunningFacingRight = "🏃‍♂️‍➡️"
    case womanDancing = "💃"
    case manDancing = "🕺"
    case personInSuitLevitating = "🕴️"
    case peopleWithBunnyEars = "👯"
    case menWithBunnyEars = "👯‍♂️"
    case womenWithBunnyEars = "👯‍♀️"
    case personInSteamyRoom = "🧖"
    case manInSteamyRoom = "🧖‍♂️"
    case womanInSteamyRoom = "🧖‍♀️"
    case personClimbing = "🧗"
    case manClimbing = "🧗‍♂️"
    case womanClimbing = "🧗‍♀️"
    case personFencing = "🤺"
    case horseRacing = "🏇"
    case skier = "⛷️"
    case snowboarder = "🏂"
    case personGolfing = "🏌️"
    case manGolfing = "🏌️‍♂️"
    case womanGolfing = "🏌️‍♀️"
    case personSurfing = "🏄"
    case manSurfing = "🏄‍♂️"
    case womanSurfing = "🏄‍♀️"
    case personRowingBoat = "🚣"
    case manRowingBoat = "🚣‍♂️"
    case womanRowingBoat = "🚣‍♀️"
    case personSwimming = "🏊"
    case manSwimming = "🏊‍♂️"
    case womanSwimming = "🏊‍♀️"
    case personBouncingBall = "⛹️"
    case manBouncingBall = "⛹️‍♂️"
    case womanBouncingBall = "⛹️‍♀️"
    case personLiftingWeights = "🏋️"
    case manLiftingWeights = "🏋️‍♂️"
    case womanLiftingWeights = "🏋️‍♀️"
    case personBiking = "🚴"
    case manBiking = "🚴‍♂️"
    case womanBiking = "🚴‍♀️"
    case personMountainBiking = "🚵"
    case manMountainBiking = "🚵‍♂️"
    case womanMountainBiking = "🚵‍♀️"
    case personCartwheeling = "🤸"
    case manCartwheeling = "🤸‍♂️"
    case womanCartwheeling = "🤸‍♀️"
    case peopleWrestling = "🤼"
    case menWrestling = "🤼‍♂️"
    case womenWrestling = "🤼‍♀️"
    case personPlayingWaterPolo = "🤽"
    case manPlayingWaterPolo = "🤽‍♂️"
    case womanPlayingWaterPolo = "🤽‍♀️"
    case personPlayingHandball = "🤾"
    case manPlayingHandball = "🤾‍♂️"
    case womanPlayingHandball = "🤾‍♀️"
    case personJuggling = "🤹"
    case manJuggling = "🤹‍♂️"
    case womanJuggling = "🤹‍♀️"
    case personInLotusPosition = "🧘"
    case manInLotusPosition = "🧘‍♂️"
    case womanInLotusPosition = "🧘‍♀️"
    case personTakingBath = "🛀"
    case personInBed = "🛌"
    case peopleHoldingHands = "🧑‍🤝‍🧑"
    case womenHoldingHands = "👭"
    case womanAndManHoldingHands = "👫"
    case menHoldingHands = "👬"
    case kiss = "💏"
    case kissWomanMan = "👩‍❤️‍💋‍👨"
    case kissManMan = "👨‍❤️‍💋‍👨"
    case kissWomanWoman = "👩‍❤️‍💋‍👩"
    case coupleWithHeart = "💑"
    case coupleWithHeartWomanMan = "👩‍❤️‍👨"
    case coupleWithHeartManMan = "👨‍❤️‍👨"
    case coupleWithHeartWomanWoman = "👩‍❤️‍👩"
    case familyManWomanBoy = "👨‍👩‍👦"
    case familyManWomanGirl = "👨‍👩‍👧"
    case familyManWomanGirlBoy = "👨‍👩‍👧‍👦"
    case familyManWomanBoyBoy = "👨‍👩‍👦‍👦"
    case familyManWomanGirlGirl = "👨‍👩‍👧‍👧"
    case familyManManBoy = "👨‍👨‍👦"
    case familyManManGirl = "👨‍👨‍👧"
    case familyManManGirlBoy = "👨‍👨‍👧‍👦"
    case familyManManBoyBoy = "👨‍👨‍👦‍👦"
    case familyManManGirlGirl = "👨‍👨‍👧‍👧"
    case familyWomanWomanBoy = "👩‍👩‍👦"
    case familyWomanWomanGirl = "👩‍👩‍👧"
    case familyWomanWomanGirlBoy = "👩‍👩‍👧‍👦"
    case familyWomanWomanBoyBoy = "👩‍👩‍👦‍👦"
    case familyWomanWomanGirlGirl = "👩‍👩‍👧‍👧"
    case familyManBoy = "👨‍👦"
    case familyManBoyBoy = "👨‍👦‍👦"
    case familyManGirl = "👨‍👧"
    case familyManGirlBoy = "👨‍👧‍👦"
    case familyManGirlGirl = "👨‍👧‍👧"
    case familyWomanBoy = "👩‍👦"
    case familyWomanBoyBoy = "👩‍👦‍👦"
    case familyWomanGirl = "👩‍👧"
    case familyWomanGirlBoy = "👩‍👧‍👦"
    case familyWomanGirlGirl = "👩‍👧‍👧"
    case speakingHead = "🗣️"
    case bustInSilhouette = "👤"
    case bustsInSilhouette = "👥"
    case peopleHugging = "🫂"
    case family = "👪"
    case familyAdultAdultChild = "🧑‍🧑‍🧒"
    case familyAdultAdultChildChild = "🧑‍🧑‍🧒‍🧒"
    case familyAdultChild = "🧑‍🧒"
    case familyAdultChildChild = "🧑‍🧒‍🧒"
    case footprints = "👣"
    case fingerprint = "🫆"
    case monkeyFace = "🐵"
    case monkey = "🐒"
    case gorilla = "🦍"
    case orangutan = "🦧"
    case dogFace = "🐶"
    case dog = "🐕"
    case guideDog = "🦮"
    case serviceDog = "🐕‍🦺"
    case poodle = "🐩"
    case wolf = "🐺"
    case fox = "🦊"
    case raccoon = "🦝"
    case catFace = "🐱"
    case cat = "🐈"
    case blackCat = "🐈‍⬛"
    case lion = "🦁"
    case tigerFace = "🐯"
    case tiger = "🐅"
    case leopard = "🐆"
    case horseFace = "🐴"
    case moose = "🫎"
    case donkey = "🫏"
    case horse = "🐎"
    case unicorn = "🦄"
    case zebra = "🦓"
    case deer = "🦌"
    case bison = "🦬"
    case cowFace = "🐮"
    case ox = "🐂"
    case waterBuffalo = "🐃"
    case cow = "🐄"
    case pigFace = "🐷"
    case pig = "🐖"
    case boar = "🐗"
    case pigNose = "🐽"
    case ram = "🐏"
    case ewe = "🐑"
    case goat = "🐐"
    case camel = "🐪"
    case twoHumpCamel = "🐫"
    case llama = "🦙"
    case giraffe = "🦒"
    case elephant = "🐘"
    case mammoth = "🦣"
    case rhinoceros = "🦏"
    case hippopotamus = "🦛"
    case mouseFace = "🐭"
    case mouse = "🐁"
    case rat = "🐀"
    case hamster = "🐹"
    case rabbitFace = "🐰"
    case rabbit = "🐇"
    case chipmunk = "🐿️"
    case beaver = "🦫"
    case hedgehog = "🦔"
    case bat = "🦇"
    case bear = "🐻"
    case polarBear = "🐻‍❄️"
    case koala = "🐨"
    case panda = "🐼"
    case sloth = "🦥"
    case otter = "🦦"
    case skunk = "🦨"
    case kangaroo = "🦘"
    case badger = "🦡"
    case pawPrints = "🐾"
    case turkey = "🦃"
    case chicken = "🐔"
    case rooster = "🐓"
    case hatchingChick = "🐣"
    case babyChick = "🐤"
    case frontFacingBabyChick = "🐥"
    case bird = "🐦"
    case penguin = "🐧"
    case dove = "🕊️"
    case eagle = "🦅"
    case duck = "🦆"
    case swan = "🦢"
    case owl = "🦉"
    case dodo = "🦤"
    case feather = "🪶"
    case flamingo = "🦩"
    case peacock = "🦚"
    case parrot = "🦜"
    case wing = "🪽"
    case blackBird = "🐦‍⬛"
    case goose = "🪿"
    case phoenix = "🐦‍🔥"
    case frog = "🐸"
    case crocodile = "🐊"
    case turtle = "🐢"
    case lizard = "🦎"
    case snake = "🐍"
    case dragonFace = "🐲"
    case dragon = "🐉"
    case sauropod = "🦕"
    case tRex = "🦖"
    case spoutingWhale = "🐳"
    case whale = "🐋"
    case dolphin = "🐬"
    case seal = "🦭"
    case fish = "🐟"
    case tropicalFish = "🐠"
    case blowfish = "🐡"
    case shark = "🦈"
    case octopus = "🐙"
    case spiralShell = "🐚"
    case coral = "🪸"
    case jellyfish = "🪼"
    case crab = "🦀"
    case lobster = "🦞"
    case shrimp = "🦐"
    case squid = "🦑"
    case oyster = "🦪"
    case snail = "🐌"
    case butterfly = "🦋"
    case bug = "🐛"
    case ant = "🐜"
    case honeybee = "🐝"
    case beetle = "🪲"
    case ladyBeetle = "🐞"
    case cricket = "🦗"
    case cockroach = "🪳"
    case spider = "🕷️"
    case spiderWeb = "🕸️"
    case scorpion = "🦂"
    case mosquito = "🦟"
    case fly = "🪰"
    case worm = "🪱"
    case microbe = "🦠"
    case bouquet = "💐"
    case cherryBlossom = "🌸"
    case whiteFlower = "💮"
    case lotus = "🪷"
    case rosette = "🏵️"
    case rose = "🌹"
    case wiltedFlower = "🥀"
    case hibiscus = "🌺"
    case sunflower = "🌻"
    case blossom = "🌼"
    case tulip = "🌷"
    case hyacinth = "🪻"
    case seedling = "🌱"
    case pottedPlant = "🪴"
    case evergreenTree = "🌲"
    case deciduousTree = "🌳"
    case palmTree = "🌴"
    case cactus = "🌵"
    case sheafOfRice = "🌾"
    case herb = "🌿"
    case shamrock = "☘️"
    case fourLeafClover = "🍀"
    case mapleLeaf = "🍁"
    case fallenLeaf = "🍂"
    case leafFlutteringInWind = "🍃"
    case emptyNest = "🪹"
    case nestWithEggs = "🪺"
    case mushroom = "🍄"
    case leaflessTree = "🪾"
    case grapes = "🍇"
    case melon = "🍈"
    case watermelon = "🍉"
    case tangerine = "🍊"
    case lemon = "🍋"
    case lime = "🍋‍🟩"
    case banana = "🍌"
    case pineapple = "🍍"
    case mango = "🥭"
    case redApple = "🍎"
    case greenApple = "🍏"
    case pear = "🍐"
    case peach = "🍑"
    case cherries = "🍒"
    case strawberry = "🍓"
    case blueberries = "🫐"
    case kiwiFruit = "🥝"
    case tomato = "🍅"
    case olive = "🫒"
    case coconut = "🥥"
    case avocado = "🥑"
    case eggplant = "🍆"
    case potato = "🥔"
    case carrot = "🥕"
    case earOfCorn = "🌽"
    case hotPepper = "🌶️"
    case bellPepper = "🫑"
    case cucumber = "🥒"
    case leafyGreen = "🥬"
    case broccoli = "🥦"
    case garlic = "🧄"
    case onion = "🧅"
    case peanuts = "🥜"
    case beans = "🫘"
    case chestnut = "🌰"
    case gingerRoot = "🫚"
    case peaPod = "🫛"
    case brownMushroom = "🍄‍🟫"
    case rootVegetable = "🫜"
    case bread = "🍞"
    case croissant = "🥐"
    case baguetteBread = "🥖"
    case flatbread = "🫓"
    case pretzel = "🥨"
    case bagel = "🥯"
    case pancakes = "🥞"
    case waffle = "🧇"
    case cheeseWedge = "🧀"
    case meatOnBone = "🍖"
    case poultryLeg = "🍗"
    case cutOfMeat = "🥩"
    case bacon = "🥓"
    case hamburger = "🍔"
    case frenchFries = "🍟"
    case pizza = "🍕"
    case hotDog = "🌭"
    case sandwich = "🥪"
    case taco = "🌮"
    case burrito = "🌯"
    case tamale = "🫔"
    case stuffedFlatbread = "🥙"
    case falafel = "🧆"
    case egg = "🥚"
    case cooking = "🍳"
    case shallowPanOfFood = "🥘"
    case potOfFood = "🍲"
    case fondue = "🫕"
    case bowlWithSpoon = "🥣"
    case greenSalad = "🥗"
    case popcorn = "🍿"
    case butter = "🧈"
    case salt = "🧂"
    case cannedFood = "🥫"
    case bentoBox = "🍱"
    case riceCracker = "🍘"
    case riceBall = "🍙"
    case cookedRice = "🍚"
    case curryRice = "🍛"
    case steamingBowl = "🍜"
    case spaghetti = "🍝"
    case roastedSweetPotato = "🍠"
    case oden = "🍢"
    case sushi = "🍣"
    case friedShrimp = "🍤"
    case fishCakeWithSwirl = "🍥"
    case moonCake = "🥮"
    case dango = "🍡"
    case dumpling = "🥟"
    case fortuneCookie = "🥠"
    case takeoutBox = "🥡"
    case softIceCream = "🍦"
    case shavedIce = "🍧"
    case iceCream = "🍨"
    case doughnut = "🍩"
    case cookie = "🍪"
    case birthdayCake = "🎂"
    case shortcake = "🍰"
    case cupcake = "🧁"
    case pie = "🥧"
    case chocolateBar = "🍫"
    case candy = "🍬"
    case lollipop = "🍭"
    case custard = "🍮"
    case honeyPot = "🍯"
    case babyBottle = "🍼"
    case glassOfMilk = "🥛"
    case hotBeverage = "☕"
    case teapot = "🫖"
    case teacupWithoutHandle = "🍵"
    case sake = "🍶"
    case bottleWithPoppingCork = "🍾"
    case wineGlass = "🍷"
    case cocktailGlass = "🍸"
    case tropicalDrink = "🍹"
    case beerMug = "🍺"
    case clinkingBeerMugs = "🍻"
    case clinkingGlasses = "🥂"
    case tumblerGlass = "🥃"
    case pouringLiquid = "🫗"
    case cupWithStraw = "🥤"
    case bubbleTea = "🧋"
    case beverageBox = "🧃"
    case mate = "🧉"
    case ice = "🧊"
    case chopsticks = "🥢"
    case forkAndKnifeWithPlate = "🍽️"
    case forkAndKnife = "🍴"
    case spoon = "🥄"
    case kitchenKnife = "🔪"
    case jar = "🫙"
    case amphora = "🏺"
    case globeShowingEuropeAfrica = "🌍"
    case globeShowingAmericas = "🌎"
    case globeShowingAsiaAustralia = "🌏"
    case globeWithMeridians = "🌐"
    case worldMap = "🗺️"
    case mapOfJapan = "🗾"
    case compass = "🧭"
    case snowCappedMountain = "🏔️"
    case mountain = "⛰️"
    case volcano = "🌋"
    case mountFuji = "🗻"
    case camping = "🏕️"
    case beachWithUmbrella = "🏖️"
    case desert = "🏜️"
    case desertIsland = "🏝️"
    case nationalPark = "🏞️"
    case stadium = "🏟️"
    case classicalBuilding = "🏛️"
    case buildingConstruction = "🏗️"
    case brick = "🧱"
    case rock = "🪨"
    case wood = "🪵"
    case hut = "🛖"
    case houses = "🏘️"
    case derelictHouse = "🏚️"
    case house = "🏠"
    case houseWithGarden = "🏡"
    case officeBuilding = "🏢"
    case japanesePostOffice = "🏣"
    case postOffice = "🏤"
    case hospital = "🏥"
    case bank = "🏦"
    case hotel = "🏨"
    case loveHotel = "🏩"
    case convenienceStore = "🏪"
    case school = "🏫"
    case departmentStore = "🏬"
    case factory = "🏭"
    case japaneseCastle = "🏯"
    case castle = "🏰"
    case wedding = "💒"
    case tokyoTower = "🗼"
    case statueOfLiberty = "🗽"
    case church = "⛪"
    case mosque = "🕌"
    case hinduTemple = "🛕"
    case synagogue = "🕍"
    case shintoShrine = "⛩️"
    case kaaba = "🕋"
    case fountain = "⛲"
    case tent = "⛺"
    case foggy = "🌁"
    case nightWithStars = "🌃"
    case cityscape = "🏙️"
    case sunriseOverMountains = "🌄"
    case sunrise = "🌅"
    case cityscapeAtDusk = "🌆"
    case sunset = "🌇"
    case bridgeAtNight = "🌉"
    case hotSprings = "♨️"
    case carouselHorse = "🎠"
    case playgroundSlide = "🛝"
    case ferrisWheel = "🎡"
    case rollerCoaster = "🎢"
    case barberPole = "💈"
    case circusTent = "🎪"
    case locomotive = "🚂"
    case railwayCar = "🚃"
    case highSpeedTrain = "🚄"
    case bulletTrain = "🚅"
    case train = "🚆"
    case metro = "🚇"
    case lightRail = "🚈"
    case station = "🚉"
    case tram = "🚊"
    case monorail = "🚝"
    case mountainRailway = "🚞"
    case tramCar = "🚋"
    case bus = "🚌"
    case oncomingBus = "🚍"
    case trolleybus = "🚎"
    case minibus = "🚐"
    case ambulance = "🚑"
    case fireEngine = "🚒"
    case policeCar = "🚓"
    case oncomingPoliceCar = "🚔"
    case taxi = "🚕"
    case oncomingTaxi = "🚖"
    case automobile = "🚗"
    case oncomingAutomobile = "🚘"
    case sportUtilityVehicle = "🚙"
    case pickupTruck = "🛻"
    case deliveryTruck = "🚚"
    case articulatedLorry = "🚛"
    case tractor = "🚜"
    case racingCar = "🏎️"
    case motorcycle = "🏍️"
    case motorScooter = "🛵"
    case manualWheelchair = "🦽"
    case motorizedWheelchair = "🦼"
    case autoRickshaw = "🛺"
    case bicycle = "🚲"
    case kickScooter = "🛴"
    case skateboard = "🛹"
    case rollerSkate = "🛼"
    case busStop = "🚏"
    case motorway = "🛣️"
    case railwayTrack = "🛤️"
    case oilDrum = "🛢️"
    case fuelPump = "⛽"
    case wheel = "🛞"
    case policeCarLight = "🚨"
    case horizontalTrafficLight = "🚥"
    case verticalTrafficLight = "🚦"
    case stopSign = "🛑"
    case construction = "🚧"
    case anchor = "⚓"
    case ringBuoy = "🛟"
    case sailboat = "⛵"
    case canoe = "🛶"
    case speedboat = "🚤"
    case passengerShip = "🛳️"
    case ferry = "⛴️"
    case motorBoat = "🛥️"
    case ship = "🚢"
    case airplane = "✈️"
    case smallAirplane = "🛩️"
    case airplaneDeparture = "🛫"
    case airplaneArrival = "🛬"
    case parachute = "🪂"
    case seat = "💺"
    case helicopter = "🚁"
    case suspensionRailway = "🚟"
    case mountainCableway = "🚠"
    case aerialTramway = "🚡"
    case satellite = "🛰️"
    case rocket = "🚀"
    case flyingSaucer = "🛸"
    case bellhopBell = "🛎️"
    case luggage = "🧳"
    case hourglassDone = "⌛"
    case hourglassNotDone = "⏳"
    case watch = "⌚"
    case alarmClock = "⏰"
    case stopwatch = "⏱️"
    case timerClock = "⏲️"
    case mantelpieceClock = "🕰️"
    case twelveOClock = "🕛"
    case twelveThirty = "🕧"
    case oneOClock = "🕐"
    case oneThirty = "🕜"
    case twoOClock = "🕑"
    case twoThirty = "🕝"
    case threeOClock = "🕒"
    case threeThirty = "🕞"
    case fourOClock = "🕓"
    case fourThirty = "🕟"
    case fiveOClock = "🕔"
    case fiveThirty = "🕠"
    case sixOClock = "🕕"
    case sixThirty = "🕡"
    case sevenOClock = "🕖"
    case sevenThirty = "🕢"
    case eightOClock = "🕗"
    case eightThirty = "🕣"
    case nineOClock = "🕘"
    case nineThirty = "🕤"
    case tenOClock = "🕙"
    case tenThirty = "🕥"
    case elevenOClock = "🕚"
    case elevenThirty = "🕦"
    case newMoon = "🌑"
    case waxingCrescentMoon = "🌒"
    case firstQuarterMoon = "🌓"
    case waxingGibbousMoon = "🌔"
    case fullMoon = "🌕"
    case waningGibbousMoon = "🌖"
    case lastQuarterMoon = "🌗"
    case waningCrescentMoon = "🌘"
    case crescentMoon = "🌙"
    case newMoonFace = "🌚"
    case firstQuarterMoonFace = "🌛"
    case lastQuarterMoonFace = "🌜"
    case thermometer = "🌡️"
    case sun = "☀️"
    case fullMoonFace = "🌝"
    case sunWithFace = "🌞"
    case ringedPlanet = "🪐"
    case star = "⭐"
    case glowingStar = "🌟"
    case shootingStar = "🌠"
    case milkyWay = "🌌"
    case cloud = "☁️"
    case sunBehindCloud = "⛅"
    case cloudWithLightningAndRain = "⛈️"
    case sunBehindSmallCloud = "🌤️"
    case sunBehindLargeCloud = "🌥️"
    case sunBehindRainCloud = "🌦️"
    case cloudWithRain = "🌧️"
    case cloudWithSnow = "🌨️"
    case cloudWithLightning = "🌩️"
    case tornado = "🌪️"
    case fog = "🌫️"
    case windFace = "🌬️"
    case cyclone = "🌀"
    case rainbow = "🌈"
    case closedUmbrella = "🌂"
    case umbrella = "☂️"
    case umbrellaWithRainDrops = "☔"
    case umbrellaOnGround = "⛱️"
    case highVoltage = "⚡"
    case snowflake = "❄️"
    case snowman = "☃️"
    case snowmanWithoutSnow = "⛄"
    case comet = "☄️"
    case fire = "🔥"
    case droplet = "💧"
    case waterWave = "🌊"
    case jackOLantern = "🎃"
    case christmasTree = "🎄"
    case fireworks = "🎆"
    case sparkler = "🎇"
    case firecracker = "🧨"
    case sparkles = "✨"
    case balloon = "🎈"
    case partyPopper = "🎉"
    case confettiBall = "🎊"
    case tanabataTree = "🎋"
    case pineDecoration = "🎍"
    case japaneseDolls = "🎎"
    case carpStreamer = "🎏"
    case windChime = "🎐"
    case moonViewingCeremony = "🎑"
    case redEnvelope = "🧧"
    case ribbon = "🎀"
    case wrappedGift = "🎁"
    case reminderRibbon = "🎗️"
    case admissionTickets = "🎟️"
    case ticket = "🎫"
    case militaryMedal = "🎖️"
    case trophy = "🏆"
    case sportsMedal = "🏅"
    case firstPlaceMedal = "🥇"
    case secondPlaceMedal = "🥈"
    case thirdPlaceMedal = "🥉"
    case soccerBall = "⚽"
    case baseball = "⚾"
    case softball = "🥎"
    case basketball = "🏀"
    case volleyball = "🏐"
    case americanFootball = "🏈"
    case rugbyFootball = "🏉"
    case tennis = "🎾"
    case flyingDisc = "🥏"
    case bowling = "🎳"
    case cricketGame = "🏏"
    case fieldHockey = "🏑"
    case iceHockey = "🏒"
    case lacrosse = "🥍"
    case pingPong = "🏓"
    case badminton = "🏸"
    case boxingGlove = "🥊"
    case martialArtsUniform = "🥋"
    case goalNet = "🥅"
    case flagInHole = "⛳"
    case iceSkate = "⛸️"
    case fishingPole = "🎣"
    case divingMask = "🤿"
    case runningShirt = "🎽"
    case skis = "🎿"
    case sled = "🛷"
    case curlingStone = "🥌"
    case bullseye = "🎯"
    case yoYo = "🪀"
    case kite = "🪁"
    case waterPistol = "🔫"
    case pool8Ball = "🎱"
    case crystalBall = "🔮"
    case magicWand = "🪄"
    case videoGame = "🎮"
    case joystick = "🕹️"
    case slotMachine = "🎰"
    case gameDie = "🎲"
    case puzzlePiece = "🧩"
    case teddyBear = "🧸"
    case pinata = "🪅"
    case mirrorBall = "🪩"
    case nestingDolls = "🪆"
    case spadeSuit = "♠️"
    case heartSuit = "♥️"
    case diamondSuit = "♦️"
    case clubSuit = "♣️"
    case chessPawn = "♟️"
    case joker = "🃏"
    case mahjongRedDragon = "🀄"
    case flowerPlayingCards = "🎴"
    case performingArts = "🎭"
    case framedPicture = "🖼️"
    case artistPalette = "🎨"
    case thread = "🧵"
    case sewingNeedle = "🪡"
    case yarn = "🧶"
    case knot = "🪢"
    case glasses = "👓"
    case sunglasses = "🕶️"
    case goggles = "🥽"
    case labCoat = "🥼"
    case safetyVest = "🦺"
    case necktie = "👔"
    case tShirt = "👕"
    case jeans = "👖"
    case scarf = "🧣"
    case gloves = "🧤"
    case coat = "🧥"
    case socks = "🧦"
    case dress = "👗"
    case kimono = "👘"
    case sari = "🥻"
    case onePieceSwimsuit = "🩱"
    case briefs = "🩲"
    case shorts = "🩳"
    case bikini = "👙"
    case womanSClothes = "👚"
    case foldingHandFan = "🪭"
    case purse = "👛"
    case handbag = "👜"
    case clutchBag = "👝"
    case shoppingBags = "🛍️"
    case backpack = "🎒"
    case thongSandal = "🩴"
    case manSShoe = "👞"
    case runningShoe = "👟"
    case hikingBoot = "🥾"
    case flatShoe = "🥿"
    case highHeeledShoe = "👠"
    case womanSSandal = "👡"
    case balletShoes = "🩰"
    case womanSBoot = "👢"
    case hairPick = "🪮"
    case crown = "👑"
    case womanSHat = "👒"
    case topHat = "🎩"
    case graduationCap = "🎓"
    case billedCap = "🧢"
    case militaryHelmet = "🪖"
    case rescueWorkerSHelmet = "⛑️"
    case prayerBeads = "📿"
    case lipstick = "💄"
    case ring = "💍"
    case gemStone = "💎"
    case mutedSpeaker = "🔇"
    case speakerLowVolume = "🔈"
    case speakerMediumVolume = "🔉"
    case speakerHighVolume = "🔊"
    case loudspeaker = "📢"
    case megaphone = "📣"
    case postalHorn = "📯"
    case bell = "🔔"
    case bellWithSlash = "🔕"
    case musicalScore = "🎼"
    case musicalNote = "🎵"
    case musicalNotes = "🎶"
    case studioMicrophone = "🎙️"
    case levelSlider = "🎚️"
    case controlKnobs = "🎛️"
    case microphone = "🎤"
    case headphone = "🎧"
    case radio = "📻"
    case saxophone = "🎷"
    case accordion = "🪗"
    case guitar = "🎸"
    case musicalKeyboard = "🎹"
    case trumpet = "🎺"
    case violin = "🎻"
    case banjo = "🪕"
    case drum = "🥁"
    case longDrum = "🪘"
    case maracas = "🪇"
    case flute = "🪈"
    case harp = "🪉"
    case mobilePhone = "📱"
    case mobilePhoneWithArrow = "📲"
    case telephone = "☎️"
    case telephoneReceiver = "📞"
    case pager = "📟"
    case faxMachine = "📠"
    case battery = "🔋"
    case lowBattery = "🪫"
    case electricPlug = "🔌"
    case laptop = "💻"
    case desktopComputer = "🖥️"
    case printer = "🖨️"
    case keyboard = "⌨️"
    case computerMouse = "🖱️"
    case trackball = "🖲️"
    case computerDisk = "💽"
    case floppyDisk = "💾"
    case opticalDisk = "💿"
    case dvd = "📀"
    case abacus = "🧮"
    case movieCamera = "🎥"
    case filmFrames = "🎞️"
    case filmProjector = "📽️"
    case clapperBoard = "🎬"
    case television = "📺"
    case camera = "📷"
    case cameraWithFlash = "📸"
    case videoCamera = "📹"
    case videocassette = "📼"
    case magnifyingGlassTiltedLeft = "🔍"
    case magnifyingGlassTiltedRight = "🔎"
    case candle = "🕯️"
    case lightBulb = "💡"
    case flashlight = "🔦"
    case redPaperLantern = "🏮"
    case diyaLamp = "🪔"
    case notebookWithDecorativeCover = "📔"
    case closedBook = "📕"
    case openBook = "📖"
    case greenBook = "📗"
    case blueBook = "📘"
    case orangeBook = "📙"
    case books = "📚"
    case notebook = "📓"
    case ledger = "📒"
    case pageWithCurl = "📃"
    case scroll = "📜"
    case pageFacingUp = "📄"
    case newspaper = "📰"
    case rolledUpNewspaper = "🗞️"
    case bookmarkTabs = "📑"
    case bookmark = "🔖"
    case label = "🏷️"
    case moneyBag = "💰"
    case coin = "🪙"
    case yenBanknote = "💴"
    case dollarBanknote = "💵"
    case euroBanknote = "💶"
    case poundBanknote = "💷"
    case moneyWithWings = "💸"
    case creditCard = "💳"
    case receipt = "🧾"
    case chartIncreasingWithYen = "💹"
    case envelope = "✉️"
    case eMail = "📧"
    case incomingEnvelope = "📨"
    case envelopeWithArrow = "📩"
    case outboxTray = "📤"
    case inboxTray = "📥"
    case package = "📦"
    case closedMailboxWithRaisedFlag = "📫"
    case closedMailboxWithLoweredFlag = "📪"
    case openMailboxWithRaisedFlag = "📬"
    case openMailboxWithLoweredFlag = "📭"
    case postbox = "📮"
    case ballotBoxWithBallot = "🗳️"
    case pencil = "✏️"
    case blackNib = "✒️"
    case fountainPen = "🖋️"
    case pen = "🖊️"
    case paintbrush = "🖌️"
    case crayon = "🖍️"
    case memo = "📝"
    case briefcase = "💼"
    case fileFolder = "📁"
    case openFileFolder = "📂"
    case cardIndexDividers = "🗂️"
    case calendar = "📅"
    case tearOffCalendar = "📆"
    case spiralNotepad = "🗒️"
    case spiralCalendar = "🗓️"
    case cardIndex = "📇"
    case chartIncreasing = "📈"
    case chartDecreasing = "📉"
    case barChart = "📊"
    case clipboard = "📋"
    case pushpin = "📌"
    case roundPushpin = "📍"
    case paperclip = "📎"
    case linkedPaperclips = "🖇️"
    case straightRuler = "📏"
    case triangularRuler = "📐"
    case scissors = "✂️"
    case cardFileBox = "🗃️"
    case fileCabinet = "🗄️"
    case wastebasket = "🗑️"
    case locked = "🔒"
    case unlocked = "🔓"
    case lockedWithPen = "🔏"
    case lockedWithKey = "🔐"
    case key = "🔑"
    case oldKey = "🗝️"
    case hammer = "🔨"
    case axe = "🪓"
    case pick = "⛏️"
    case hammerAndPick = "⚒️"
    case hammerAndWrench = "🛠️"
    case dagger = "🗡️"
    case crossedSwords = "⚔️"
    case bomb = "💣"
    case boomerang = "🪃"
    case bowAndArrow = "🏹"
    case shield = "🛡️"
    case carpentrySaw = "🪚"
    case wrench = "🔧"
    case screwdriver = "🪛"
    case nutAndBolt = "🔩"
    case gear = "⚙️"
    case clamp = "🗜️"
    case balanceScale = "⚖️"
    case whiteCane = "🦯"
    case link = "🔗"
    case brokenChain = "⛓️‍💥"
    case chains = "⛓️"
    case hook = "🪝"
    case toolbox = "🧰"
    case magnet = "🧲"
    case ladder = "🪜"
    case shovel = "🪏"
    case alembic = "⚗️"
    case testTube = "🧪"
    case petriDish = "🧫"
    case dna = "🧬"
    case microscope = "🔬"
    case telescope = "🔭"
    case satelliteAntenna = "📡"
    case syringe = "💉"
    case dropOfBlood = "🩸"
    case pill = "💊"
    case adhesiveBandage = "🩹"
    case crutch = "🩼"
    case stethoscope = "🩺"
    case xRay = "🩻"
    case door = "🚪"
    case elevator = "🛗"
    case mirror = "🪞"
    case window = "🪟"
    case bed = "🛏️"
    case couchAndLamp = "🛋️"
    case chair = "🪑"
    case toilet = "🚽"
    case plunger = "🪠"
    case shower = "🚿"
    case bathtub = "🛁"
    case mouseTrap = "🪤"
    case razor = "🪒"
    case lotionBottle = "🧴"
    case safetyPin = "🧷"
    case broom = "🧹"
    case basket = "🧺"
    case rollOfPaper = "🧻"
    case bucket = "🪣"
    case soap = "🧼"
    case bubbles = "🫧"
    case toothbrush = "🪥"
    case sponge = "🧽"
    case fireExtinguisher = "🧯"
    case shoppingCart = "🛒"
    case cigarette = "🚬"
    case coffin = "⚰️"
    case headstone = "🪦"
    case funeralUrn = "⚱️"
    case nazarAmulet = "🧿"
    case hamsa = "🪬"
    case moai = "🗿"
    case placard = "🪧"
    case identificationCard = "🪪"
    case atmSign = "🏧"
    case litterInBinSign = "🚮"
    case potableWater = "🚰"
    case wheelchairSymbol = "♿"
    case menSRoom = "🚹"
    case womenSRoom = "🚺"
    case restroom = "🚻"
    case babySymbol = "🚼"
    case waterCloset = "🚾"
    case passportControl = "🛂"
    case customs = "🛃"
    case baggageClaim = "🛄"
    case leftLuggage = "🛅"
    case warning = "⚠️"
    case childrenCrossing = "🚸"
    case noEntry = "⛔"
    case prohibited = "🚫"
    case noBicycles = "🚳"
    case noSmoking = "🚭"
    case noLittering = "🚯"
    case nonPotableWater = "🚱"
    case noPedestrians = "🚷"
    case noMobilePhones = "📵"
    case noOneUnderEighteen = "🔞"
    case radioactive = "☢️"
    case biohazard = "☣️"
    case upArrow = "⬆️"
    case upRightArrow = "↗️"
    case rightArrow = "➡️"
    case downRightArrow = "↘️"
    case downArrow = "⬇️"
    case downLeftArrow = "↙️"
    case leftArrow = "⬅️"
    case upLeftArrow = "↖️"
    case upDownArrow = "↕️"
    case leftRightArrow = "↔️"
    case rightArrowCurvingLeft = "↩️"
    case leftArrowCurvingRight = "↪️"
    case rightArrowCurvingUp = "⤴️"
    case rightArrowCurvingDown = "⤵️"
    case clockwiseVerticalArrows = "🔃"
    case counterclockwiseArrowsButton = "🔄"
    case backArrow = "🔙"
    case endArrow = "🔚"
    case onArrow = "🔛"
    case soonArrow = "🔜"
    case topArrow = "🔝"
    case placeOfWorship = "🛐"
    case atomSymbol = "⚛️"
    case om = "🕉️"
    case starOfDavid = "✡️"
    case wheelOfDharma = "☸️"
    case yinYang = "☯️"
    case latinCross = "✝️"
    case orthodoxCross = "☦️"
    case starAndCrescent = "☪️"
    case peaceSymbol = "☮️"
    case menorah = "🕎"
    case dottedSixPointedStar = "🔯"
    case khanda = "🪯"
    case aries = "♈"
    case taurus = "♉"
    case gemini = "♊"
    case cancer = "♋"
    case leo = "♌"
    case virgo = "♍"
    case libra = "♎"
    case scorpio = "♏"
    case sagittarius = "♐"
    case capricorn = "♑"
    case aquarius = "♒"
    case pisces = "♓"
    case ophiuchus = "⛎"
    case shuffleTracksButton = "🔀"
    case repeatButton = "🔁"
    case repeatSingleButton = "🔂"
    case playButton = "▶️"
    case fastForwardButton = "⏩"
    case nextTrackButton = "⏭️"
    case playOrPauseButton = "⏯️"
    case reverseButton = "◀️"
    case fastReverseButton = "⏪"
    case lastTrackButton = "⏮️"
    case upwardsButton = "🔼"
    case fastUpButton = "⏫"
    case downwardsButton = "🔽"
    case fastDownButton = "⏬"
    case pauseButton = "⏸️"
    case stopButton = "⏹️"
    case recordButton = "⏺️"
    case ejectButton = "⏏️"
    case cinema = "🎦"
    case dimButton = "🔅"
    case brightButton = "🔆"
    case antennaBars = "📶"
    case wireless = "🛜"
    case vibrationMode = "📳"
    case mobilePhoneOff = "📴"
    case femaleSign = "♀️"
    case maleSign = "♂️"
    case transgenderSymbol = "⚧️"
    case multiply = "✖️"
    case plus = "➕"
    case minus = "➖"
    case divide = "➗"
    case heavyEqualsSign = "🟰"
    case infinity = "♾️"
    case doubleExclamationMark = "‼️"
    case exclamationQuestionMark = "⁉️"
    case redQuestionMark = "❓"
    case whiteQuestionMark = "❔"
    case whiteExclamationMark = "❕"
    case redExclamationMark = "❗"
    case wavyDash = "〰️"
    case currencyExchange = "💱"
    case heavyDollarSign = "💲"
    case medicalSymbol = "⚕️"
    case recyclingSymbol = "♻️"
    case fleurDeLis = "⚜️"
    case tridentEmblem = "🔱"
    case nameBadge = "📛"
    case japaneseSymbolForBeginner = "🔰"
    case hollowRedCircle = "⭕"
    case checkMarkButton = "✅"
    case checkBoxWithCheck = "☑️"
    case checkMark = "✔️"
    case crossMark = "❌"
    case crossMarkButton = "❎"
    case curlyLoop = "➰"
    case doubleCurlyLoop = "➿"
    case partAlternationMark = "〽️"
    case eightSpokedAsterisk = "✳️"
    case eightPointedStar = "✴️"
    case sparkle = "❇️"
    case copyright = "©️"
    case registered = "®️"
    case tradeMark = "™️"
    case splatter = "🫟"
    case keycapRoute = "#️⃣"
    case keycapStar = "*️⃣"
    case keycap0 = "0️⃣"
    case keycap1 = "1️⃣"
    case keycap2 = "2️⃣"
    case keycap3 = "3️⃣"
    case keycap4 = "4️⃣"
    case keycap5 = "5️⃣"
    case keycap6 = "6️⃣"
    case keycap7 = "7️⃣"
    case keycap8 = "8️⃣"
    case keycap9 = "9️⃣"
    case keycap10 = "🔟"
    case inputLatinUppercase = "🔠"
    case inputLatinLowercase = "🔡"
    case inputNumbers = "🔢"
    case inputSymbols = "🔣"
    case inputLatinLetters = "🔤"
    case aButtonBloodType = "🅰️"
    case abButtonBloodType = "🆎"
    case bButtonBloodType = "🅱️"
    case clButton = "🆑"
    case coolButton = "🆒"
    case freeButton = "🆓"
    case information = "ℹ️"
    case idButton = "🆔"
    case circledM = "Ⓜ️"
    case newButton = "🆕"
    case ngButton = "🆖"
    case oButtonBloodType = "🅾️"
    case okButton = "🆗"
    case pButton = "🅿️"
    case sosButton = "🆘"
    case upButton = "🆙"
    case vsButton = "🆚"
    case japaneseHereButton = "🈁"
    case japaneseServiceChargeButton = "🈂️"
    case japaneseMonthlyAmountButton = "🈷️"
    case japaneseNotFreeOfChargeButton = "🈶"
    case japaneseReservedButton = "🈯"
    case japaneseBargainButton = "🉐"
    case japaneseDiscountButton = "🈹"
    case japaneseFreeOfChargeButton = "🈚"
    case japaneseProhibitedButton = "🈲"
    case japaneseAcceptableButton = "🉑"
    case japaneseApplicationButton = "🈸"
    case japanesePassingGradeButton = "🈴"
    case japaneseVacancyButton = "🈳"
    case japaneseCongratulationsButton = "㊗️"
    case japaneseSecretButton = "㊙️"
    case japaneseOpenForBusinessButton = "🈺"
    case japaneseNoVacancyButton = "🈵"
    case redCircle = "🔴"
    case orangeCircle = "🟠"
    case yellowCircle = "🟡"
    case greenCircle = "🟢"
    case blueCircle = "🔵"
    case purpleCircle = "🟣"
    case brownCircle = "🟤"
    case blackCircle = "⚫"
    case whiteCircle = "⚪"
    case redSquare = "🟥"
    case orangeSquare = "🟧"
    case yellowSquare = "🟨"
    case greenSquare = "🟩"
    case blueSquare = "🟦"
    case purpleSquare = "🟪"
    case brownSquare = "🟫"
    case blackLargeSquare = "⬛"
    case whiteLargeSquare = "⬜"
    case blackMediumSquare = "◼️"
    case whiteMediumSquare = "◻️"
    case blackMediumSmallSquare = "◾"
    case whiteMediumSmallSquare = "◽"
    case blackSmallSquare = "▪️"
    case whiteSmallSquare = "▫️"
    case largeOrangeDiamond = "🔶"
    case largeBlueDiamond = "🔷"
    case smallOrangeDiamond = "🔸"
    case smallBlueDiamond = "🔹"
    case redTrianglePointedUp = "🔺"
    case redTrianglePointedDown = "🔻"
    case diamondWithADot = "💠"
    case radioButton = "🔘"
    case whiteSquareButton = "🔳"
    case blackSquareButton = "🔲"
    case chequeredFlag = "🏁"
    case triangularFlag = "🚩"
    case crossedFlags = "🎌"
    case blackFlag = "🏴"
    case whiteFlag = "🏳️"
    case rainbowFlag = "🏳️‍🌈"
    case transgenderFlag = "🏳️‍⚧️"
    case pirateFlag = "🏴‍☠️"
    case flagAscensionIsland = "🇦🇨"
    case flagAndorra = "🇦🇩"
    case flagUnitedArabEmirates = "🇦🇪"
    case flagAfghanistan = "🇦🇫"
    case flagAntiguaBarbuda = "🇦🇬"
    case flagAnguilla = "🇦🇮"
    case flagAlbania = "🇦🇱"
    case flagArmenia = "🇦🇲"
    case flagAngola = "🇦🇴"
    case flagAntarctica = "🇦🇶"
    case flagArgentina = "🇦🇷"
    case flagAmericanSamoa = "🇦🇸"
    case flagAustria = "🇦🇹"
    case flagAustralia = "🇦🇺"
    case flagAruba = "🇦🇼"
    case flagAlandIslands = "🇦🇽"
    case flagAzerbaijan = "🇦🇿"
    case flagBosniaHerzegovina = "🇧🇦"
    case flagBarbados = "🇧🇧"
    case flagBangladesh = "🇧🇩"
    case flagBelgium = "🇧🇪"
    case flagBurkinaFaso = "🇧🇫"
    case flagBulgaria = "🇧🇬"
    case flagBahrain = "🇧🇭"
    case flagBurundi = "🇧🇮"
    case flagBenin = "🇧🇯"
    case flagStBarthelemy = "🇧🇱"
    case flagBermuda = "🇧🇲"
    case flagBrunei = "🇧🇳"
    case flagBolivia = "🇧🇴"
    case flagCaribbeanNetherlands = "🇧🇶"
    case flagBrazil = "🇧🇷"
    case flagBahamas = "🇧🇸"
    case flagBhutan = "🇧🇹"
    case flagBouvetIsland = "🇧🇻"
    case flagBotswana = "🇧🇼"
    case flagBelarus = "🇧🇾"
    case flagBelize = "🇧🇿"
    case flagCanada = "🇨🇦"
    case flagCocosKeelingIslands = "🇨🇨"
    case flagCongoKinshasa = "🇨🇩"
    case flagCentralAfricanRepublic = "🇨🇫"
    case flagCongoBrazzaville = "🇨🇬"
    case flagSwitzerland = "🇨🇭"
    case flagCoteDIvoire = "🇨🇮"
    case flagCookIslands = "🇨🇰"
    case flagChile = "🇨🇱"
    case flagCameroon = "🇨🇲"
    case flagChina = "🇨🇳"
    case flagColombia = "🇨🇴"
    case flagClippertonIsland = "🇨🇵"
    case flagSark = "🇨🇶"
    case flagCostaRica = "🇨🇷"
    case flagCuba = "🇨🇺"
    case flagCapeVerde = "🇨🇻"
    case flagCuracao = "🇨🇼"
    case flagChristmasIsland = "🇨🇽"
    case flagCyprus = "🇨🇾"
    case flagCzechia = "🇨🇿"
    case flagGermany = "🇩🇪"
    case flagDiegoGarcia = "🇩🇬"
    case flagDjibouti = "🇩🇯"
    case flagDenmark = "🇩🇰"
    case flagDominica = "🇩🇲"
    case flagDominicanRepublic = "🇩🇴"
    case flagAlgeria = "🇩🇿"
    case flagCeutaMelilla = "🇪🇦"
    case flagEcuador = "🇪🇨"
    case flagEstonia = "🇪🇪"
    case flagEgypt = "🇪🇬"
    case flagWesternSahara = "🇪🇭"
    case flagEritrea = "🇪🇷"
    case flagSpain = "🇪🇸"
    case flagEthiopia = "🇪🇹"
    case flagEuropeanUnion = "🇪🇺"
    case flagFinland = "🇫🇮"
    case flagFiji = "🇫🇯"
    case flagFalklandIslands = "🇫🇰"
    case flagMicronesia = "🇫🇲"
    case flagFaroeIslands = "🇫🇴"
    case flagFrance = "🇫🇷"
    case flagGabon = "🇬🇦"
    case flagUnitedKingdom = "🇬🇧"
    case flagGrenada = "🇬🇩"
    case flagGeorgia = "🇬🇪"
    case flagFrenchGuiana = "🇬🇫"
    case flagGuernsey = "🇬🇬"
    case flagGhana = "🇬🇭"
    case flagGibraltar = "🇬🇮"
    case flagGreenland = "🇬🇱"
    case flagGambia = "🇬🇲"
    case flagGuinea = "🇬🇳"
    case flagGuadeloupe = "🇬🇵"
    case flagEquatorialGuinea = "🇬🇶"
    case flagGreece = "🇬🇷"
    case flagSouthGeorgiaSouthSandwichIslands = "🇬🇸"
    case flagGuatemala = "🇬🇹"
    case flagGuam = "🇬🇺"
    case flagGuineaBissau = "🇬🇼"
    case flagGuyana = "🇬🇾"
    case flagHongKongSarChina = "🇭🇰"
    case flagHeardMcdonaldIslands = "🇭🇲"
    case flagHonduras = "🇭🇳"
    case flagCroatia = "🇭🇷"
    case flagHaiti = "🇭🇹"
    case flagHungary = "🇭🇺"
    case flagCanaryIslands = "🇮🇨"
    case flagIndonesia = "🇮🇩"
    case flagIreland = "🇮🇪"
    case flagIsrael = "🇮🇱"
    case flagIsleOfMan = "🇮🇲"
    case flagIndia = "🇮🇳"
    case flagBritishIndianOceanTerritory = "🇮🇴"
    case flagIraq = "🇮🇶"
    case flagIran = "🇮🇷"
    case flagIceland = "🇮🇸"
    case flagItaly = "🇮🇹"
    case flagJersey = "🇯🇪"
    case flagJamaica = "🇯🇲"
    case flagJordan = "🇯🇴"
    case flagJapan = "🇯🇵"
    case flagKenya = "🇰🇪"
    case flagKyrgyzstan = "🇰🇬"
    case flagCambodia = "🇰🇭"
    case flagKiribati = "🇰🇮"
    case flagComoros = "🇰🇲"
    case flagStKittsNevis = "🇰🇳"
    case flagNorthKorea = "🇰🇵"
    case flagSouthKorea = "🇰🇷"
    case flagKuwait = "🇰🇼"
    case flagCaymanIslands = "🇰🇾"
    case flagKazakhstan = "🇰🇿"
    case flagLaos = "🇱🇦"
    case flagLebanon = "🇱🇧"
    case flagStLucia = "🇱🇨"
    case flagLiechtenstein = "🇱🇮"
    case flagSriLanka = "🇱🇰"
    case flagLiberia = "🇱🇷"
    case flagLesotho = "🇱🇸"
    case flagLithuania = "🇱🇹"
    case flagLuxembourg = "🇱🇺"
    case flagLatvia = "🇱🇻"
    case flagLibya = "🇱🇾"
    case flagMorocco = "🇲🇦"
    case flagMonaco = "🇲🇨"
    case flagMoldova = "🇲🇩"
    case flagMontenegro = "🇲🇪"
    case flagStMartin = "🇲🇫"
    case flagMadagascar = "🇲🇬"
    case flagMarshallIslands = "🇲🇭"
    case flagNorthMacedonia = "🇲🇰"
    case flagMali = "🇲🇱"
    case flagMyanmarBurma = "🇲🇲"
    case flagMongolia = "🇲🇳"
    case flagMacaoSarChina = "🇲🇴"
    case flagNorthernMarianaIslands = "🇲🇵"
    case flagMartinique = "🇲🇶"
    case flagMauritania = "🇲🇷"
    case flagMontserrat = "🇲🇸"
    case flagMalta = "🇲🇹"
    case flagMauritius = "🇲🇺"
    case flagMaldives = "🇲🇻"
    case flagMalawi = "🇲🇼"
    case flagMexico = "🇲🇽"
    case flagMalaysia = "🇲🇾"
    case flagMozambique = "🇲🇿"
    case flagNamibia = "🇳🇦"
    case flagNewCaledonia = "🇳🇨"
    case flagNiger = "🇳🇪"
    case flagNorfolkIsland = "🇳🇫"
    case flagNigeria = "🇳🇬"
    case flagNicaragua = "🇳🇮"
    case flagNetherlands = "🇳🇱"
    case flagNorway = "🇳🇴"
    case flagNepal = "🇳🇵"
    case flagNauru = "🇳🇷"
    case flagNiue = "🇳🇺"
    case flagNewZealand = "🇳🇿"
    case flagOman = "🇴🇲"
    case flagPanama = "🇵🇦"
    case flagPeru = "🇵🇪"
    case flagFrenchPolynesia = "🇵🇫"
    case flagPapuaNewGuinea = "🇵🇬"
    case flagPhilippines = "🇵🇭"
    case flagPakistan = "🇵🇰"
    case flagPoland = "🇵🇱"
    case flagStPierreMiquelon = "🇵🇲"
    case flagPitcairnIslands = "🇵🇳"
    case flagPuertoRico = "🇵🇷"
    case flagPalestinianTerritories = "🇵🇸"
    case flagPortugal = "🇵🇹"
    case flagPalau = "🇵🇼"
    case flagParaguay = "🇵🇾"
    case flagQatar = "🇶🇦"
    case flagReunion = "🇷🇪"
    case flagRomania = "🇷🇴"
    case flagSerbia = "🇷🇸"
    case flagRussia = "🇷🇺"
    case flagRwanda = "🇷🇼"
    case flagSaudiArabia = "🇸🇦"
    case flagSolomonIslands = "🇸🇧"
    case flagSeychelles = "🇸🇨"
    case flagSudan = "🇸🇩"
    case flagSweden = "🇸🇪"
    case flagSingapore = "🇸🇬"
    case flagStHelena = "🇸🇭"
    case flagSlovenia = "🇸🇮"
    case flagSvalbardJanMayen = "🇸🇯"
    case flagSlovakia = "🇸🇰"
    case flagSierraLeone = "🇸🇱"
    case flagSanMarino = "🇸🇲"
    case flagSenegal = "🇸🇳"
    case flagSomalia = "🇸🇴"
    case flagSuriname = "🇸🇷"
    case flagSouthSudan = "🇸🇸"
    case flagSaoTomePrincipe = "🇸🇹"
    case flagElSalvador = "🇸🇻"
    case flagSintMaarten = "🇸🇽"
    case flagSyria = "🇸🇾"
    case flagEswatini = "🇸🇿"
    case flagTristanDaCunha = "🇹🇦"
    case flagTurksCaicosIslands = "🇹🇨"
    case flagChad = "🇹🇩"
    case flagFrenchSouthernTerritories = "🇹🇫"
    case flagTogo = "🇹🇬"
    case flagThailand = "🇹🇭"
    case flagTajikistan = "🇹🇯"
    case flagTokelau = "🇹🇰"
    case flagTimorLeste = "🇹🇱"
    case flagTurkmenistan = "🇹🇲"
    case flagTunisia = "🇹🇳"
    case flagTonga = "🇹🇴"
    case flagTurkiye = "🇹🇷"
    case flagTrinidadTobago = "🇹🇹"
    case flagTuvalu = "🇹🇻"
    case flagTaiwan = "🇹🇼"
    case flagTanzania = "🇹🇿"
    case flagUkraine = "🇺🇦"
    case flagUganda = "🇺🇬"
    case flagUSOutlyingIslands = "🇺🇲"
    case flagUnitedNations = "🇺🇳"
    case flagUnitedStates = "🇺🇸"
    case flagUruguay = "🇺🇾"
    case flagUzbekistan = "🇺🇿"
    case flagVaticanCity = "🇻🇦"
    case flagStVincentGrenadines = "🇻🇨"
    case flagVenezuela = "🇻🇪"
    case flagBritishVirginIslands = "🇻🇬"
    case flagUSVirginIslands = "🇻🇮"
    case flagVietnam = "🇻🇳"
    case flagVanuatu = "🇻🇺"
    case flagWallisFutuna = "🇼🇫"
    case flagSamoa = "🇼🇸"
    case flagKosovo = "🇽🇰"
    case flagYemen = "🇾🇪"
    case flagMayotte = "🇾🇹"
    case flagSouthAfrica = "🇿🇦"
    case flagZambia = "🇿🇲"
    case flagZimbabwe = "🇿🇼"
    case flagEngland = "🏴󠁧󠁢󠁥󠁮󠁧󠁿"
    case flagScotland = "🏴󠁧󠁢󠁳󠁣󠁴󠁿"
    case flagWales = "🏴󠁧󠁢󠁷󠁬󠁳󠁿"

    public var id: Self { self }

    public var sortOrder: Int {
      switch self {
       case .grinningFace:
            0
       case .grinningFaceWithBigEyes:
            1
       case .grinningFaceWithSmilingEyes:
            2
       case .beamingFaceWithSmilingEyes:
            3
       case .grinningSquintingFace:
            4
       case .grinningFaceWithSweat:
            5
       case .rollingOnTheFloorLaughing:
            6
       case .faceWithTearsOfJoy:
            7
       case .slightlySmilingFace:
            8
       case .upsideDownFace:
            9
       case .meltingFace:
            10
       case .winkingFace:
            11
       case .smilingFaceWithSmilingEyes:
            12
       case .smilingFaceWithHalo:
            13
       case .smilingFaceWithHearts:
            14
       case .smilingFaceWithHeartEyes:
            15
       case .starStruck:
            16
       case .faceBlowingAKiss:
            17
       case .kissingFace:
            18
       case .smilingFace:
            19
       case .kissingFaceWithClosedEyes:
            20
       case .kissingFaceWithSmilingEyes:
            21
       case .smilingFaceWithTear:
            22
       case .faceSavoringFood:
            23
       case .faceWithTongue:
            24
       case .winkingFaceWithTongue:
            25
       case .zanyFace:
            26
       case .squintingFaceWithTongue:
            27
       case .moneyMouthFace:
            28
       case .smilingFaceWithOpenHands:
            29
       case .faceWithHandOverMouth:
            30
       case .faceWithOpenEyesAndHandOverMouth:
            31
       case .faceWithPeekingEye:
            32
       case .shushingFace:
            33
       case .thinkingFace:
            34
       case .salutingFace:
            35
       case .zipperMouthFace:
            36
       case .faceWithRaisedEyebrow:
            37
       case .neutralFace:
            38
       case .expressionlessFace:
            39
       case .faceWithoutMouth:
            40
       case .dottedLineFace:
            41
       case .faceInClouds:
            42
       case .smirkingFace:
            43
       case .unamusedFace:
            44
       case .faceWithRollingEyes:
            45
       case .grimacingFace:
            46
       case .faceExhaling:
            47
       case .lyingFace:
            48
       case .shakingFace:
            49
       case .headShakingHorizontally:
            50
       case .headShakingVertically:
            51
       case .relievedFace:
            52
       case .pensiveFace:
            53
       case .sleepyFace:
            54
       case .droolingFace:
            55
       case .sleepingFace:
            56
       case .faceWithBagsUnderEyes:
            57
       case .faceWithMedicalMask:
            58
       case .faceWithThermometer:
            59
       case .faceWithHeadBandage:
            60
       case .nauseatedFace:
            61
       case .faceVomiting:
            62
       case .sneezingFace:
            63
       case .hotFace:
            64
       case .coldFace:
            65
       case .woozyFace:
            66
       case .faceWithCrossedOutEyes:
            67
       case .faceWithSpiralEyes:
            68
       case .explodingHead:
            69
       case .cowboyHatFace:
            70
       case .partyingFace:
            71
       case .disguisedFace:
            72
       case .smilingFaceWithSunglasses:
            73
       case .nerdFace:
            74
       case .faceWithMonocle:
            75
       case .confusedFace:
            76
       case .faceWithDiagonalMouth:
            77
       case .worriedFace:
            78
       case .slightlyFrowningFace:
            79
       case .frowningFace:
            80
       case .faceWithOpenMouth:
            81
       case .hushedFace:
            82
       case .astonishedFace:
            83
       case .flushedFace:
            84
       case .pleadingFace:
            85
       case .faceHoldingBackTears:
            86
       case .frowningFaceWithOpenMouth:
            87
       case .anguishedFace:
            88
       case .fearfulFace:
            89
       case .anxiousFaceWithSweat:
            90
       case .sadButRelievedFace:
            91
       case .cryingFace:
            92
       case .loudlyCryingFace:
            93
       case .faceScreamingInFear:
            94
       case .confoundedFace:
            95
       case .perseveringFace:
            96
       case .disappointedFace:
            97
       case .downcastFaceWithSweat:
            98
       case .wearyFace:
            99
       case .tiredFace:
            100
       case .yawningFace:
            101
       case .faceWithSteamFromNose:
            102
       case .enragedFace:
            103
       case .angryFace:
            104
       case .faceWithSymbolsOnMouth:
            105
       case .smilingFaceWithHorns:
            106
       case .angryFaceWithHorns:
            107
       case .skull:
            108
       case .skullAndCrossbones:
            109
       case .pileOfPoo:
            110
       case .clownFace:
            111
       case .ogre:
            112
       case .goblin:
            113
       case .ghost:
            114
       case .alien:
            115
       case .alienMonster:
            116
       case .robot:
            117
       case .grinningCat:
            118
       case .grinningCatWithSmilingEyes:
            119
       case .catWithTearsOfJoy:
            120
       case .smilingCatWithHeartEyes:
            121
       case .catWithWrySmile:
            122
       case .kissingCat:
            123
       case .wearyCat:
            124
       case .cryingCat:
            125
       case .poutingCat:
            126
       case .seeNoEvilMonkey:
            127
       case .hearNoEvilMonkey:
            128
       case .speakNoEvilMonkey:
            129
       case .loveLetter:
            130
       case .heartWithArrow:
            131
       case .heartWithRibbon:
            132
       case .sparklingHeart:
            133
       case .growingHeart:
            134
       case .beatingHeart:
            135
       case .revolvingHearts:
            136
       case .twoHearts:
            137
       case .heartDecoration:
            138
       case .heartExclamation:
            139
       case .brokenHeart:
            140
       case .heartOnFire:
            141
       case .mendingHeart:
            142
       case .redHeart:
            143
       case .pinkHeart:
            144
       case .orangeHeart:
            145
       case .yellowHeart:
            146
       case .greenHeart:
            147
       case .blueHeart:
            148
       case .lightBlueHeart:
            149
       case .purpleHeart:
            150
       case .brownHeart:
            151
       case .blackHeart:
            152
       case .greyHeart:
            153
       case .whiteHeart:
            154
       case .kissMark:
            155
       case .hundredPoints:
            156
       case .angerSymbol:
            157
       case .collision:
            158
       case .dizzy:
            159
       case .sweatDroplets:
            160
       case .dashingAway:
            161
       case .hole:
            162
       case .speechBalloon:
            163
       case .eyeInSpeechBubble:
            164
       case .leftSpeechBubble:
            165
       case .rightAngerBubble:
            166
       case .thoughtBalloon:
            167
       case .zzz:
            168
       case .wavingHand:
            169
       case .raisedBackOfHand:
            170
       case .handWithFingersSplayed:
            171
       case .raisedHand:
            172
       case .vulcanSalute:
            173
       case .rightwardsHand:
            174
       case .leftwardsHand:
            175
       case .palmDownHand:
            176
       case .palmUpHand:
            177
       case .leftwardsPushingHand:
            178
       case .rightwardsPushingHand:
            179
       case .okHand:
            180
       case .pinchedFingers:
            181
       case .pinchingHand:
            182
       case .victoryHand:
            183
       case .crossedFingers:
            184
       case .handWithIndexFingerAndThumbCrossed:
            185
       case .loveYouGesture:
            186
       case .signOfTheHorns:
            187
       case .callMeHand:
            188
       case .backhandIndexPointingLeft:
            189
       case .backhandIndexPointingRight:
            190
       case .backhandIndexPointingUp:
            191
       case .middleFinger:
            192
       case .backhandIndexPointingDown:
            193
       case .indexPointingUp:
            194
       case .indexPointingAtTheViewer:
            195
       case .thumbsUp:
            196
       case .thumbsDown:
            197
       case .raisedFist:
            198
       case .oncomingFist:
            199
       case .leftFacingFist:
            200
       case .rightFacingFist:
            201
       case .clappingHands:
            202
       case .raisingHands:
            203
       case .heartHands:
            204
       case .openHands:
            205
       case .palmsUpTogether:
            206
       case .handshake:
            207
       case .foldedHands:
            208
       case .writingHand:
            209
       case .nailPolish:
            210
       case .selfie:
            211
       case .flexedBiceps:
            212
       case .mechanicalArm:
            213
       case .mechanicalLeg:
            214
       case .leg:
            215
       case .foot:
            216
       case .ear:
            217
       case .earWithHearingAid:
            218
       case .nose:
            219
       case .brain:
            220
       case .anatomicalHeart:
            221
       case .lungs:
            222
       case .tooth:
            223
       case .bone:
            224
       case .eyes:
            225
       case .eye:
            226
       case .tongue:
            227
       case .mouth:
            228
       case .bitingLip:
            229
       case .baby:
            230
       case .child:
            231
       case .boy:
            232
       case .girl:
            233
       case .person:
            234
       case .personBlondHair:
            235
       case .man:
            236
       case .personBeard:
            237
       case .manBeard:
            238
       case .womanBeard:
            239
       case .manRedHair:
            240
       case .manCurlyHair:
            241
       case .manWhiteHair:
            242
       case .manBald:
            243
       case .woman:
            244
       case .womanRedHair:
            245
       case .personRedHair:
            246
       case .womanCurlyHair:
            247
       case .personCurlyHair:
            248
       case .womanWhiteHair:
            249
       case .personWhiteHair:
            250
       case .womanBald:
            251
       case .personBald:
            252
       case .womanBlondHair:
            253
       case .manBlondHair:
            254
       case .olderPerson:
            255
       case .oldMan:
            256
       case .oldWoman:
            257
       case .personFrowning:
            258
       case .manFrowning:
            259
       case .womanFrowning:
            260
       case .personPouting:
            261
       case .manPouting:
            262
       case .womanPouting:
            263
       case .personGesturingNo:
            264
       case .manGesturingNo:
            265
       case .womanGesturingNo:
            266
       case .personGesturingOk:
            267
       case .manGesturingOk:
            268
       case .womanGesturingOk:
            269
       case .personTippingHand:
            270
       case .manTippingHand:
            271
       case .womanTippingHand:
            272
       case .personRaisingHand:
            273
       case .manRaisingHand:
            274
       case .womanRaisingHand:
            275
       case .deafPerson:
            276
       case .deafMan:
            277
       case .deafWoman:
            278
       case .personBowing:
            279
       case .manBowing:
            280
       case .womanBowing:
            281
       case .personFacepalming:
            282
       case .manFacepalming:
            283
       case .womanFacepalming:
            284
       case .personShrugging:
            285
       case .manShrugging:
            286
       case .womanShrugging:
            287
       case .healthWorker:
            288
       case .manHealthWorker:
            289
       case .womanHealthWorker:
            290
       case .student:
            291
       case .manStudent:
            292
       case .womanStudent:
            293
       case .teacher:
            294
       case .manTeacher:
            295
       case .womanTeacher:
            296
       case .judge:
            297
       case .manJudge:
            298
       case .womanJudge:
            299
       case .farmer:
            300
       case .manFarmer:
            301
       case .womanFarmer:
            302
       case .cook:
            303
       case .manCook:
            304
       case .womanCook:
            305
       case .mechanic:
            306
       case .manMechanic:
            307
       case .womanMechanic:
            308
       case .factoryWorker:
            309
       case .manFactoryWorker:
            310
       case .womanFactoryWorker:
            311
       case .officeWorker:
            312
       case .manOfficeWorker:
            313
       case .womanOfficeWorker:
            314
       case .scientist:
            315
       case .manScientist:
            316
       case .womanScientist:
            317
       case .technologist:
            318
       case .manTechnologist:
            319
       case .womanTechnologist:
            320
       case .singer:
            321
       case .manSinger:
            322
       case .womanSinger:
            323
       case .artist:
            324
       case .manArtist:
            325
       case .womanArtist:
            326
       case .pilot:
            327
       case .manPilot:
            328
       case .womanPilot:
            329
       case .astronaut:
            330
       case .manAstronaut:
            331
       case .womanAstronaut:
            332
       case .firefighter:
            333
       case .manFirefighter:
            334
       case .womanFirefighter:
            335
       case .policeOfficer:
            336
       case .manPoliceOfficer:
            337
       case .womanPoliceOfficer:
            338
       case .detective:
            339
       case .manDetective:
            340
       case .womanDetective:
            341
       case .personGuard:
            342
       case .manGuard:
            343
       case .womanGuard:
            344
       case .ninja:
            345
       case .constructionWorker:
            346
       case .manConstructionWorker:
            347
       case .womanConstructionWorker:
            348
       case .personWithCrown:
            349
       case .prince:
            350
       case .princess:
            351
       case .personWearingTurban:
            352
       case .manWearingTurban:
            353
       case .womanWearingTurban:
            354
       case .personWithSkullcap:
            355
       case .womanWithHeadscarf:
            356
       case .personInTuxedo:
            357
       case .manInTuxedo:
            358
       case .womanInTuxedo:
            359
       case .personWithVeil:
            360
       case .manWithVeil:
            361
       case .womanWithVeil:
            362
       case .pregnantWoman:
            363
       case .pregnantMan:
            364
       case .pregnantPerson:
            365
       case .breastFeeding:
            366
       case .womanFeedingBaby:
            367
       case .manFeedingBaby:
            368
       case .personFeedingBaby:
            369
       case .babyAngel:
            370
       case .santaClaus:
            371
       case .mrsClaus:
            372
       case .mxClaus:
            373
       case .superhero:
            374
       case .manSuperhero:
            375
       case .womanSuperhero:
            376
       case .supervillain:
            377
       case .manSupervillain:
            378
       case .womanSupervillain:
            379
       case .mage:
            380
       case .manMage:
            381
       case .womanMage:
            382
       case .fairy:
            383
       case .manFairy:
            384
       case .womanFairy:
            385
       case .vampire:
            386
       case .manVampire:
            387
       case .womanVampire:
            388
       case .merperson:
            389
       case .merman:
            390
       case .mermaid:
            391
       case .elf:
            392
       case .manElf:
            393
       case .womanElf:
            394
       case .genie:
            395
       case .manGenie:
            396
       case .womanGenie:
            397
       case .zombie:
            398
       case .manZombie:
            399
       case .womanZombie:
            400
       case .troll:
            401
       case .personGettingMassage:
            402
       case .manGettingMassage:
            403
       case .womanGettingMassage:
            404
       case .personGettingHaircut:
            405
       case .manGettingHaircut:
            406
       case .womanGettingHaircut:
            407
       case .personWalking:
            408
       case .manWalking:
            409
       case .womanWalking:
            410
       case .personWalkingFacingRight:
            411
       case .womanWalkingFacingRight:
            412
       case .manWalkingFacingRight:
            413
       case .personStanding:
            414
       case .manStanding:
            415
       case .womanStanding:
            416
       case .personKneeling:
            417
       case .manKneeling:
            418
       case .womanKneeling:
            419
       case .personKneelingFacingRight:
            420
       case .womanKneelingFacingRight:
            421
       case .manKneelingFacingRight:
            422
       case .personWithWhiteCane:
            423
       case .personWithWhiteCaneFacingRight:
            424
       case .manWithWhiteCane:
            425
       case .manWithWhiteCaneFacingRight:
            426
       case .womanWithWhiteCane:
            427
       case .womanWithWhiteCaneFacingRight:
            428
       case .personInMotorizedWheelchair:
            429
       case .personInMotorizedWheelchairFacingRight:
            430
       case .manInMotorizedWheelchair:
            431
       case .manInMotorizedWheelchairFacingRight:
            432
       case .womanInMotorizedWheelchair:
            433
       case .womanInMotorizedWheelchairFacingRight:
            434
       case .personInManualWheelchair:
            435
       case .personInManualWheelchairFacingRight:
            436
       case .manInManualWheelchair:
            437
       case .manInManualWheelchairFacingRight:
            438
       case .womanInManualWheelchair:
            439
       case .womanInManualWheelchairFacingRight:
            440
       case .personRunning:
            441
       case .manRunning:
            442
       case .womanRunning:
            443
       case .personRunningFacingRight:
            444
       case .womanRunningFacingRight:
            445
       case .manRunningFacingRight:
            446
       case .womanDancing:
            447
       case .manDancing:
            448
       case .personInSuitLevitating:
            449
       case .peopleWithBunnyEars:
            450
       case .menWithBunnyEars:
            451
       case .womenWithBunnyEars:
            452
       case .personInSteamyRoom:
            453
       case .manInSteamyRoom:
            454
       case .womanInSteamyRoom:
            455
       case .personClimbing:
            456
       case .manClimbing:
            457
       case .womanClimbing:
            458
       case .personFencing:
            459
       case .horseRacing:
            460
       case .skier:
            461
       case .snowboarder:
            462
       case .personGolfing:
            463
       case .manGolfing:
            464
       case .womanGolfing:
            465
       case .personSurfing:
            466
       case .manSurfing:
            467
       case .womanSurfing:
            468
       case .personRowingBoat:
            469
       case .manRowingBoat:
            470
       case .womanRowingBoat:
            471
       case .personSwimming:
            472
       case .manSwimming:
            473
       case .womanSwimming:
            474
       case .personBouncingBall:
            475
       case .manBouncingBall:
            476
       case .womanBouncingBall:
            477
       case .personLiftingWeights:
            478
       case .manLiftingWeights:
            479
       case .womanLiftingWeights:
            480
       case .personBiking:
            481
       case .manBiking:
            482
       case .womanBiking:
            483
       case .personMountainBiking:
            484
       case .manMountainBiking:
            485
       case .womanMountainBiking:
            486
       case .personCartwheeling:
            487
       case .manCartwheeling:
            488
       case .womanCartwheeling:
            489
       case .peopleWrestling:
            490
       case .menWrestling:
            491
       case .womenWrestling:
            492
       case .personPlayingWaterPolo:
            493
       case .manPlayingWaterPolo:
            494
       case .womanPlayingWaterPolo:
            495
       case .personPlayingHandball:
            496
       case .manPlayingHandball:
            497
       case .womanPlayingHandball:
            498
       case .personJuggling:
            499
       case .manJuggling:
            500
       case .womanJuggling:
            501
       case .personInLotusPosition:
            502
       case .manInLotusPosition:
            503
       case .womanInLotusPosition:
            504
       case .personTakingBath:
            505
       case .personInBed:
            506
       case .peopleHoldingHands:
            507
       case .womenHoldingHands:
            508
       case .womanAndManHoldingHands:
            509
       case .menHoldingHands:
            510
       case .kiss:
            511
       case .kissWomanMan:
            512
       case .kissManMan:
            513
       case .kissWomanWoman:
            514
       case .coupleWithHeart:
            515
       case .coupleWithHeartWomanMan:
            516
       case .coupleWithHeartManMan:
            517
       case .coupleWithHeartWomanWoman:
            518
       case .familyManWomanBoy:
            519
       case .familyManWomanGirl:
            520
       case .familyManWomanGirlBoy:
            521
       case .familyManWomanBoyBoy:
            522
       case .familyManWomanGirlGirl:
            523
       case .familyManManBoy:
            524
       case .familyManManGirl:
            525
       case .familyManManGirlBoy:
            526
       case .familyManManBoyBoy:
            527
       case .familyManManGirlGirl:
            528
       case .familyWomanWomanBoy:
            529
       case .familyWomanWomanGirl:
            530
       case .familyWomanWomanGirlBoy:
            531
       case .familyWomanWomanBoyBoy:
            532
       case .familyWomanWomanGirlGirl:
            533
       case .familyManBoy:
            534
       case .familyManBoyBoy:
            535
       case .familyManGirl:
            536
       case .familyManGirlBoy:
            537
       case .familyManGirlGirl:
            538
       case .familyWomanBoy:
            539
       case .familyWomanBoyBoy:
            540
       case .familyWomanGirl:
            541
       case .familyWomanGirlBoy:
            542
       case .familyWomanGirlGirl:
            543
       case .speakingHead:
            544
       case .bustInSilhouette:
            545
       case .bustsInSilhouette:
            546
       case .peopleHugging:
            547
       case .family:
            548
       case .familyAdultAdultChild:
            549
       case .familyAdultAdultChildChild:
            550
       case .familyAdultChild:
            551
       case .familyAdultChildChild:
            552
       case .footprints:
            553
       case .fingerprint:
            554
       case .monkeyFace:
            555
       case .monkey:
            556
       case .gorilla:
            557
       case .orangutan:
            558
       case .dogFace:
            559
       case .dog:
            560
       case .guideDog:
            561
       case .serviceDog:
            562
       case .poodle:
            563
       case .wolf:
            564
       case .fox:
            565
       case .raccoon:
            566
       case .catFace:
            567
       case .cat:
            568
       case .blackCat:
            569
       case .lion:
            570
       case .tigerFace:
            571
       case .tiger:
            572
       case .leopard:
            573
       case .horseFace:
            574
       case .moose:
            575
       case .donkey:
            576
       case .horse:
            577
       case .unicorn:
            578
       case .zebra:
            579
       case .deer:
            580
       case .bison:
            581
       case .cowFace:
            582
       case .ox:
            583
       case .waterBuffalo:
            584
       case .cow:
            585
       case .pigFace:
            586
       case .pig:
            587
       case .boar:
            588
       case .pigNose:
            589
       case .ram:
            590
       case .ewe:
            591
       case .goat:
            592
       case .camel:
            593
       case .twoHumpCamel:
            594
       case .llama:
            595
       case .giraffe:
            596
       case .elephant:
            597
       case .mammoth:
            598
       case .rhinoceros:
            599
       case .hippopotamus:
            600
       case .mouseFace:
            601
       case .mouse:
            602
       case .rat:
            603
       case .hamster:
            604
       case .rabbitFace:
            605
       case .rabbit:
            606
       case .chipmunk:
            607
       case .beaver:
            608
       case .hedgehog:
            609
       case .bat:
            610
       case .bear:
            611
       case .polarBear:
            612
       case .koala:
            613
       case .panda:
            614
       case .sloth:
            615
       case .otter:
            616
       case .skunk:
            617
       case .kangaroo:
            618
       case .badger:
            619
       case .pawPrints:
            620
       case .turkey:
            621
       case .chicken:
            622
       case .rooster:
            623
       case .hatchingChick:
            624
       case .babyChick:
            625
       case .frontFacingBabyChick:
            626
       case .bird:
            627
       case .penguin:
            628
       case .dove:
            629
       case .eagle:
            630
       case .duck:
            631
       case .swan:
            632
       case .owl:
            633
       case .dodo:
            634
       case .feather:
            635
       case .flamingo:
            636
       case .peacock:
            637
       case .parrot:
            638
       case .wing:
            639
       case .blackBird:
            640
       case .goose:
            641
       case .phoenix:
            642
       case .frog:
            643
       case .crocodile:
            644
       case .turtle:
            645
       case .lizard:
            646
       case .snake:
            647
       case .dragonFace:
            648
       case .dragon:
            649
       case .sauropod:
            650
       case .tRex:
            651
       case .spoutingWhale:
            652
       case .whale:
            653
       case .dolphin:
            654
       case .seal:
            655
       case .fish:
            656
       case .tropicalFish:
            657
       case .blowfish:
            658
       case .shark:
            659
       case .octopus:
            660
       case .spiralShell:
            661
       case .coral:
            662
       case .jellyfish:
            663
       case .crab:
            664
       case .lobster:
            665
       case .shrimp:
            666
       case .squid:
            667
       case .oyster:
            668
       case .snail:
            669
       case .butterfly:
            670
       case .bug:
            671
       case .ant:
            672
       case .honeybee:
            673
       case .beetle:
            674
       case .ladyBeetle:
            675
       case .cricket:
            676
       case .cockroach:
            677
       case .spider:
            678
       case .spiderWeb:
            679
       case .scorpion:
            680
       case .mosquito:
            681
       case .fly:
            682
       case .worm:
            683
       case .microbe:
            684
       case .bouquet:
            685
       case .cherryBlossom:
            686
       case .whiteFlower:
            687
       case .lotus:
            688
       case .rosette:
            689
       case .rose:
            690
       case .wiltedFlower:
            691
       case .hibiscus:
            692
       case .sunflower:
            693
       case .blossom:
            694
       case .tulip:
            695
       case .hyacinth:
            696
       case .seedling:
            697
       case .pottedPlant:
            698
       case .evergreenTree:
            699
       case .deciduousTree:
            700
       case .palmTree:
            701
       case .cactus:
            702
       case .sheafOfRice:
            703
       case .herb:
            704
       case .shamrock:
            705
       case .fourLeafClover:
            706
       case .mapleLeaf:
            707
       case .fallenLeaf:
            708
       case .leafFlutteringInWind:
            709
       case .emptyNest:
            710
       case .nestWithEggs:
            711
       case .mushroom:
            712
       case .leaflessTree:
            713
       case .grapes:
            714
       case .melon:
            715
       case .watermelon:
            716
       case .tangerine:
            717
       case .lemon:
            718
       case .lime:
            719
       case .banana:
            720
       case .pineapple:
            721
       case .mango:
            722
       case .redApple:
            723
       case .greenApple:
            724
       case .pear:
            725
       case .peach:
            726
       case .cherries:
            727
       case .strawberry:
            728
       case .blueberries:
            729
       case .kiwiFruit:
            730
       case .tomato:
            731
       case .olive:
            732
       case .coconut:
            733
       case .avocado:
            734
       case .eggplant:
            735
       case .potato:
            736
       case .carrot:
            737
       case .earOfCorn:
            738
       case .hotPepper:
            739
       case .bellPepper:
            740
       case .cucumber:
            741
       case .leafyGreen:
            742
       case .broccoli:
            743
       case .garlic:
            744
       case .onion:
            745
       case .peanuts:
            746
       case .beans:
            747
       case .chestnut:
            748
       case .gingerRoot:
            749
       case .peaPod:
            750
       case .brownMushroom:
            751
       case .rootVegetable:
            752
       case .bread:
            753
       case .croissant:
            754
       case .baguetteBread:
            755
       case .flatbread:
            756
       case .pretzel:
            757
       case .bagel:
            758
       case .pancakes:
            759
       case .waffle:
            760
       case .cheeseWedge:
            761
       case .meatOnBone:
            762
       case .poultryLeg:
            763
       case .cutOfMeat:
            764
       case .bacon:
            765
       case .hamburger:
            766
       case .frenchFries:
            767
       case .pizza:
            768
       case .hotDog:
            769
       case .sandwich:
            770
       case .taco:
            771
       case .burrito:
            772
       case .tamale:
            773
       case .stuffedFlatbread:
            774
       case .falafel:
            775
       case .egg:
            776
       case .cooking:
            777
       case .shallowPanOfFood:
            778
       case .potOfFood:
            779
       case .fondue:
            780
       case .bowlWithSpoon:
            781
       case .greenSalad:
            782
       case .popcorn:
            783
       case .butter:
            784
       case .salt:
            785
       case .cannedFood:
            786
       case .bentoBox:
            787
       case .riceCracker:
            788
       case .riceBall:
            789
       case .cookedRice:
            790
       case .curryRice:
            791
       case .steamingBowl:
            792
       case .spaghetti:
            793
       case .roastedSweetPotato:
            794
       case .oden:
            795
       case .sushi:
            796
       case .friedShrimp:
            797
       case .fishCakeWithSwirl:
            798
       case .moonCake:
            799
       case .dango:
            800
       case .dumpling:
            801
       case .fortuneCookie:
            802
       case .takeoutBox:
            803
       case .softIceCream:
            804
       case .shavedIce:
            805
       case .iceCream:
            806
       case .doughnut:
            807
       case .cookie:
            808
       case .birthdayCake:
            809
       case .shortcake:
            810
       case .cupcake:
            811
       case .pie:
            812
       case .chocolateBar:
            813
       case .candy:
            814
       case .lollipop:
            815
       case .custard:
            816
       case .honeyPot:
            817
       case .babyBottle:
            818
       case .glassOfMilk:
            819
       case .hotBeverage:
            820
       case .teapot:
            821
       case .teacupWithoutHandle:
            822
       case .sake:
            823
       case .bottleWithPoppingCork:
            824
       case .wineGlass:
            825
       case .cocktailGlass:
            826
       case .tropicalDrink:
            827
       case .beerMug:
            828
       case .clinkingBeerMugs:
            829
       case .clinkingGlasses:
            830
       case .tumblerGlass:
            831
       case .pouringLiquid:
            832
       case .cupWithStraw:
            833
       case .bubbleTea:
            834
       case .beverageBox:
            835
       case .mate:
            836
       case .ice:
            837
       case .chopsticks:
            838
       case .forkAndKnifeWithPlate:
            839
       case .forkAndKnife:
            840
       case .spoon:
            841
       case .kitchenKnife:
            842
       case .jar:
            843
       case .amphora:
            844
       case .globeShowingEuropeAfrica:
            845
       case .globeShowingAmericas:
            846
       case .globeShowingAsiaAustralia:
            847
       case .globeWithMeridians:
            848
       case .worldMap:
            849
       case .mapOfJapan:
            850
       case .compass:
            851
       case .snowCappedMountain:
            852
       case .mountain:
            853
       case .volcano:
            854
       case .mountFuji:
            855
       case .camping:
            856
       case .beachWithUmbrella:
            857
       case .desert:
            858
       case .desertIsland:
            859
       case .nationalPark:
            860
       case .stadium:
            861
       case .classicalBuilding:
            862
       case .buildingConstruction:
            863
       case .brick:
            864
       case .rock:
            865
       case .wood:
            866
       case .hut:
            867
       case .houses:
            868
       case .derelictHouse:
            869
       case .house:
            870
       case .houseWithGarden:
            871
       case .officeBuilding:
            872
       case .japanesePostOffice:
            873
       case .postOffice:
            874
       case .hospital:
            875
       case .bank:
            876
       case .hotel:
            877
       case .loveHotel:
            878
       case .convenienceStore:
            879
       case .school:
            880
       case .departmentStore:
            881
       case .factory:
            882
       case .japaneseCastle:
            883
       case .castle:
            884
       case .wedding:
            885
       case .tokyoTower:
            886
       case .statueOfLiberty:
            887
       case .church:
            888
       case .mosque:
            889
       case .hinduTemple:
            890
       case .synagogue:
            891
       case .shintoShrine:
            892
       case .kaaba:
            893
       case .fountain:
            894
       case .tent:
            895
       case .foggy:
            896
       case .nightWithStars:
            897
       case .cityscape:
            898
       case .sunriseOverMountains:
            899
       case .sunrise:
            900
       case .cityscapeAtDusk:
            901
       case .sunset:
            902
       case .bridgeAtNight:
            903
       case .hotSprings:
            904
       case .carouselHorse:
            905
       case .playgroundSlide:
            906
       case .ferrisWheel:
            907
       case .rollerCoaster:
            908
       case .barberPole:
            909
       case .circusTent:
            910
       case .locomotive:
            911
       case .railwayCar:
            912
       case .highSpeedTrain:
            913
       case .bulletTrain:
            914
       case .train:
            915
       case .metro:
            916
       case .lightRail:
            917
       case .station:
            918
       case .tram:
            919
       case .monorail:
            920
       case .mountainRailway:
            921
       case .tramCar:
            922
       case .bus:
            923
       case .oncomingBus:
            924
       case .trolleybus:
            925
       case .minibus:
            926
       case .ambulance:
            927
       case .fireEngine:
            928
       case .policeCar:
            929
       case .oncomingPoliceCar:
            930
       case .taxi:
            931
       case .oncomingTaxi:
            932
       case .automobile:
            933
       case .oncomingAutomobile:
            934
       case .sportUtilityVehicle:
            935
       case .pickupTruck:
            936
       case .deliveryTruck:
            937
       case .articulatedLorry:
            938
       case .tractor:
            939
       case .racingCar:
            940
       case .motorcycle:
            941
       case .motorScooter:
            942
       case .manualWheelchair:
            943
       case .motorizedWheelchair:
            944
       case .autoRickshaw:
            945
       case .bicycle:
            946
       case .kickScooter:
            947
       case .skateboard:
            948
       case .rollerSkate:
            949
       case .busStop:
            950
       case .motorway:
            951
       case .railwayTrack:
            952
       case .oilDrum:
            953
       case .fuelPump:
            954
       case .wheel:
            955
       case .policeCarLight:
            956
       case .horizontalTrafficLight:
            957
       case .verticalTrafficLight:
            958
       case .stopSign:
            959
       case .construction:
            960
       case .anchor:
            961
       case .ringBuoy:
            962
       case .sailboat:
            963
       case .canoe:
            964
       case .speedboat:
            965
       case .passengerShip:
            966
       case .ferry:
            967
       case .motorBoat:
            968
       case .ship:
            969
       case .airplane:
            970
       case .smallAirplane:
            971
       case .airplaneDeparture:
            972
       case .airplaneArrival:
            973
       case .parachute:
            974
       case .seat:
            975
       case .helicopter:
            976
       case .suspensionRailway:
            977
       case .mountainCableway:
            978
       case .aerialTramway:
            979
       case .satellite:
            980
       case .rocket:
            981
       case .flyingSaucer:
            982
       case .bellhopBell:
            983
       case .luggage:
            984
       case .hourglassDone:
            985
       case .hourglassNotDone:
            986
       case .watch:
            987
       case .alarmClock:
            988
       case .stopwatch:
            989
       case .timerClock:
            990
       case .mantelpieceClock:
            991
       case .twelveOClock:
            992
       case .twelveThirty:
            993
       case .oneOClock:
            994
       case .oneThirty:
            995
       case .twoOClock:
            996
       case .twoThirty:
            997
       case .threeOClock:
            998
       case .threeThirty:
            999
       case .fourOClock:
            1000
       case .fourThirty:
            1001
       case .fiveOClock:
            1002
       case .fiveThirty:
            1003
       case .sixOClock:
            1004
       case .sixThirty:
            1005
       case .sevenOClock:
            1006
       case .sevenThirty:
            1007
       case .eightOClock:
            1008
       case .eightThirty:
            1009
       case .nineOClock:
            1010
       case .nineThirty:
            1011
       case .tenOClock:
            1012
       case .tenThirty:
            1013
       case .elevenOClock:
            1014
       case .elevenThirty:
            1015
       case .newMoon:
            1016
       case .waxingCrescentMoon:
            1017
       case .firstQuarterMoon:
            1018
       case .waxingGibbousMoon:
            1019
       case .fullMoon:
            1020
       case .waningGibbousMoon:
            1021
       case .lastQuarterMoon:
            1022
       case .waningCrescentMoon:
            1023
       case .crescentMoon:
            1024
       case .newMoonFace:
            1025
       case .firstQuarterMoonFace:
            1026
       case .lastQuarterMoonFace:
            1027
       case .thermometer:
            1028
       case .sun:
            1029
       case .fullMoonFace:
            1030
       case .sunWithFace:
            1031
       case .ringedPlanet:
            1032
       case .star:
            1033
       case .glowingStar:
            1034
       case .shootingStar:
            1035
       case .milkyWay:
            1036
       case .cloud:
            1037
       case .sunBehindCloud:
            1038
       case .cloudWithLightningAndRain:
            1039
       case .sunBehindSmallCloud:
            1040
       case .sunBehindLargeCloud:
            1041
       case .sunBehindRainCloud:
            1042
       case .cloudWithRain:
            1043
       case .cloudWithSnow:
            1044
       case .cloudWithLightning:
            1045
       case .tornado:
            1046
       case .fog:
            1047
       case .windFace:
            1048
       case .cyclone:
            1049
       case .rainbow:
            1050
       case .closedUmbrella:
            1051
       case .umbrella:
            1052
       case .umbrellaWithRainDrops:
            1053
       case .umbrellaOnGround:
            1054
       case .highVoltage:
            1055
       case .snowflake:
            1056
       case .snowman:
            1057
       case .snowmanWithoutSnow:
            1058
       case .comet:
            1059
       case .fire:
            1060
       case .droplet:
            1061
       case .waterWave:
            1062
       case .jackOLantern:
            1063
       case .christmasTree:
            1064
       case .fireworks:
            1065
       case .sparkler:
            1066
       case .firecracker:
            1067
       case .sparkles:
            1068
       case .balloon:
            1069
       case .partyPopper:
            1070
       case .confettiBall:
            1071
       case .tanabataTree:
            1072
       case .pineDecoration:
            1073
       case .japaneseDolls:
            1074
       case .carpStreamer:
            1075
       case .windChime:
            1076
       case .moonViewingCeremony:
            1077
       case .redEnvelope:
            1078
       case .ribbon:
            1079
       case .wrappedGift:
            1080
       case .reminderRibbon:
            1081
       case .admissionTickets:
            1082
       case .ticket:
            1083
       case .militaryMedal:
            1084
       case .trophy:
            1085
       case .sportsMedal:
            1086
       case .firstPlaceMedal:
            1087
       case .secondPlaceMedal:
            1088
       case .thirdPlaceMedal:
            1089
       case .soccerBall:
            1090
       case .baseball:
            1091
       case .softball:
            1092
       case .basketball:
            1093
       case .volleyball:
            1094
       case .americanFootball:
            1095
       case .rugbyFootball:
            1096
       case .tennis:
            1097
       case .flyingDisc:
            1098
       case .bowling:
            1099
       case .cricketGame:
            1100
       case .fieldHockey:
            1101
       case .iceHockey:
            1102
       case .lacrosse:
            1103
       case .pingPong:
            1104
       case .badminton:
            1105
       case .boxingGlove:
            1106
       case .martialArtsUniform:
            1107
       case .goalNet:
            1108
       case .flagInHole:
            1109
       case .iceSkate:
            1110
       case .fishingPole:
            1111
       case .divingMask:
            1112
       case .runningShirt:
            1113
       case .skis:
            1114
       case .sled:
            1115
       case .curlingStone:
            1116
       case .bullseye:
            1117
       case .yoYo:
            1118
       case .kite:
            1119
       case .waterPistol:
            1120
       case .pool8Ball:
            1121
       case .crystalBall:
            1122
       case .magicWand:
            1123
       case .videoGame:
            1124
       case .joystick:
            1125
       case .slotMachine:
            1126
       case .gameDie:
            1127
       case .puzzlePiece:
            1128
       case .teddyBear:
            1129
       case .pinata:
            1130
       case .mirrorBall:
            1131
       case .nestingDolls:
            1132
       case .spadeSuit:
            1133
       case .heartSuit:
            1134
       case .diamondSuit:
            1135
       case .clubSuit:
            1136
       case .chessPawn:
            1137
       case .joker:
            1138
       case .mahjongRedDragon:
            1139
       case .flowerPlayingCards:
            1140
       case .performingArts:
            1141
       case .framedPicture:
            1142
       case .artistPalette:
            1143
       case .thread:
            1144
       case .sewingNeedle:
            1145
       case .yarn:
            1146
       case .knot:
            1147
       case .glasses:
            1148
       case .sunglasses:
            1149
       case .goggles:
            1150
       case .labCoat:
            1151
       case .safetyVest:
            1152
       case .necktie:
            1153
       case .tShirt:
            1154
       case .jeans:
            1155
       case .scarf:
            1156
       case .gloves:
            1157
       case .coat:
            1158
       case .socks:
            1159
       case .dress:
            1160
       case .kimono:
            1161
       case .sari:
            1162
       case .onePieceSwimsuit:
            1163
       case .briefs:
            1164
       case .shorts:
            1165
       case .bikini:
            1166
       case .womanSClothes:
            1167
       case .foldingHandFan:
            1168
       case .purse:
            1169
       case .handbag:
            1170
       case .clutchBag:
            1171
       case .shoppingBags:
            1172
       case .backpack:
            1173
       case .thongSandal:
            1174
       case .manSShoe:
            1175
       case .runningShoe:
            1176
       case .hikingBoot:
            1177
       case .flatShoe:
            1178
       case .highHeeledShoe:
            1179
       case .womanSSandal:
            1180
       case .balletShoes:
            1181
       case .womanSBoot:
            1182
       case .hairPick:
            1183
       case .crown:
            1184
       case .womanSHat:
            1185
       case .topHat:
            1186
       case .graduationCap:
            1187
       case .billedCap:
            1188
       case .militaryHelmet:
            1189
       case .rescueWorkerSHelmet:
            1190
       case .prayerBeads:
            1191
       case .lipstick:
            1192
       case .ring:
            1193
       case .gemStone:
            1194
       case .mutedSpeaker:
            1195
       case .speakerLowVolume:
            1196
       case .speakerMediumVolume:
            1197
       case .speakerHighVolume:
            1198
       case .loudspeaker:
            1199
       case .megaphone:
            1200
       case .postalHorn:
            1201
       case .bell:
            1202
       case .bellWithSlash:
            1203
       case .musicalScore:
            1204
       case .musicalNote:
            1205
       case .musicalNotes:
            1206
       case .studioMicrophone:
            1207
       case .levelSlider:
            1208
       case .controlKnobs:
            1209
       case .microphone:
            1210
       case .headphone:
            1211
       case .radio:
            1212
       case .saxophone:
            1213
       case .accordion:
            1214
       case .guitar:
            1215
       case .musicalKeyboard:
            1216
       case .trumpet:
            1217
       case .violin:
            1218
       case .banjo:
            1219
       case .drum:
            1220
       case .longDrum:
            1221
       case .maracas:
            1222
       case .flute:
            1223
       case .harp:
            1224
       case .mobilePhone:
            1225
       case .mobilePhoneWithArrow:
            1226
       case .telephone:
            1227
       case .telephoneReceiver:
            1228
       case .pager:
            1229
       case .faxMachine:
            1230
       case .battery:
            1231
       case .lowBattery:
            1232
       case .electricPlug:
            1233
       case .laptop:
            1234
       case .desktopComputer:
            1235
       case .printer:
            1236
       case .keyboard:
            1237
       case .computerMouse:
            1238
       case .trackball:
            1239
       case .computerDisk:
            1240
       case .floppyDisk:
            1241
       case .opticalDisk:
            1242
       case .dvd:
            1243
       case .abacus:
            1244
       case .movieCamera:
            1245
       case .filmFrames:
            1246
       case .filmProjector:
            1247
       case .clapperBoard:
            1248
       case .television:
            1249
       case .camera:
            1250
       case .cameraWithFlash:
            1251
       case .videoCamera:
            1252
       case .videocassette:
            1253
       case .magnifyingGlassTiltedLeft:
            1254
       case .magnifyingGlassTiltedRight:
            1255
       case .candle:
            1256
       case .lightBulb:
            1257
       case .flashlight:
            1258
       case .redPaperLantern:
            1259
       case .diyaLamp:
            1260
       case .notebookWithDecorativeCover:
            1261
       case .closedBook:
            1262
       case .openBook:
            1263
       case .greenBook:
            1264
       case .blueBook:
            1265
       case .orangeBook:
            1266
       case .books:
            1267
       case .notebook:
            1268
       case .ledger:
            1269
       case .pageWithCurl:
            1270
       case .scroll:
            1271
       case .pageFacingUp:
            1272
       case .newspaper:
            1273
       case .rolledUpNewspaper:
            1274
       case .bookmarkTabs:
            1275
       case .bookmark:
            1276
       case .label:
            1277
       case .moneyBag:
            1278
       case .coin:
            1279
       case .yenBanknote:
            1280
       case .dollarBanknote:
            1281
       case .euroBanknote:
            1282
       case .poundBanknote:
            1283
       case .moneyWithWings:
            1284
       case .creditCard:
            1285
       case .receipt:
            1286
       case .chartIncreasingWithYen:
            1287
       case .envelope:
            1288
       case .eMail:
            1289
       case .incomingEnvelope:
            1290
       case .envelopeWithArrow:
            1291
       case .outboxTray:
            1292
       case .inboxTray:
            1293
       case .package:
            1294
       case .closedMailboxWithRaisedFlag:
            1295
       case .closedMailboxWithLoweredFlag:
            1296
       case .openMailboxWithRaisedFlag:
            1297
       case .openMailboxWithLoweredFlag:
            1298
       case .postbox:
            1299
       case .ballotBoxWithBallot:
            1300
       case .pencil:
            1301
       case .blackNib:
            1302
       case .fountainPen:
            1303
       case .pen:
            1304
       case .paintbrush:
            1305
       case .crayon:
            1306
       case .memo:
            1307
       case .briefcase:
            1308
       case .fileFolder:
            1309
       case .openFileFolder:
            1310
       case .cardIndexDividers:
            1311
       case .calendar:
            1312
       case .tearOffCalendar:
            1313
       case .spiralNotepad:
            1314
       case .spiralCalendar:
            1315
       case .cardIndex:
            1316
       case .chartIncreasing:
            1317
       case .chartDecreasing:
            1318
       case .barChart:
            1319
       case .clipboard:
            1320
       case .pushpin:
            1321
       case .roundPushpin:
            1322
       case .paperclip:
            1323
       case .linkedPaperclips:
            1324
       case .straightRuler:
            1325
       case .triangularRuler:
            1326
       case .scissors:
            1327
       case .cardFileBox:
            1328
       case .fileCabinet:
            1329
       case .wastebasket:
            1330
       case .locked:
            1331
       case .unlocked:
            1332
       case .lockedWithPen:
            1333
       case .lockedWithKey:
            1334
       case .key:
            1335
       case .oldKey:
            1336
       case .hammer:
            1337
       case .axe:
            1338
       case .pick:
            1339
       case .hammerAndPick:
            1340
       case .hammerAndWrench:
            1341
       case .dagger:
            1342
       case .crossedSwords:
            1343
       case .bomb:
            1344
       case .boomerang:
            1345
       case .bowAndArrow:
            1346
       case .shield:
            1347
       case .carpentrySaw:
            1348
       case .wrench:
            1349
       case .screwdriver:
            1350
       case .nutAndBolt:
            1351
       case .gear:
            1352
       case .clamp:
            1353
       case .balanceScale:
            1354
       case .whiteCane:
            1355
       case .link:
            1356
       case .brokenChain:
            1357
       case .chains:
            1358
       case .hook:
            1359
       case .toolbox:
            1360
       case .magnet:
            1361
       case .ladder:
            1362
       case .shovel:
            1363
       case .alembic:
            1364
       case .testTube:
            1365
       case .petriDish:
            1366
       case .dna:
            1367
       case .microscope:
            1368
       case .telescope:
            1369
       case .satelliteAntenna:
            1370
       case .syringe:
            1371
       case .dropOfBlood:
            1372
       case .pill:
            1373
       case .adhesiveBandage:
            1374
       case .crutch:
            1375
       case .stethoscope:
            1376
       case .xRay:
            1377
       case .door:
            1378
       case .elevator:
            1379
       case .mirror:
            1380
       case .window:
            1381
       case .bed:
            1382
       case .couchAndLamp:
            1383
       case .chair:
            1384
       case .toilet:
            1385
       case .plunger:
            1386
       case .shower:
            1387
       case .bathtub:
            1388
       case .mouseTrap:
            1389
       case .razor:
            1390
       case .lotionBottle:
            1391
       case .safetyPin:
            1392
       case .broom:
            1393
       case .basket:
            1394
       case .rollOfPaper:
            1395
       case .bucket:
            1396
       case .soap:
            1397
       case .bubbles:
            1398
       case .toothbrush:
            1399
       case .sponge:
            1400
       case .fireExtinguisher:
            1401
       case .shoppingCart:
            1402
       case .cigarette:
            1403
       case .coffin:
            1404
       case .headstone:
            1405
       case .funeralUrn:
            1406
       case .nazarAmulet:
            1407
       case .hamsa:
            1408
       case .moai:
            1409
       case .placard:
            1410
       case .identificationCard:
            1411
       case .atmSign:
            1412
       case .litterInBinSign:
            1413
       case .potableWater:
            1414
       case .wheelchairSymbol:
            1415
       case .menSRoom:
            1416
       case .womenSRoom:
            1417
       case .restroom:
            1418
       case .babySymbol:
            1419
       case .waterCloset:
            1420
       case .passportControl:
            1421
       case .customs:
            1422
       case .baggageClaim:
            1423
       case .leftLuggage:
            1424
       case .warning:
            1425
       case .childrenCrossing:
            1426
       case .noEntry:
            1427
       case .prohibited:
            1428
       case .noBicycles:
            1429
       case .noSmoking:
            1430
       case .noLittering:
            1431
       case .nonPotableWater:
            1432
       case .noPedestrians:
            1433
       case .noMobilePhones:
            1434
       case .noOneUnderEighteen:
            1435
       case .radioactive:
            1436
       case .biohazard:
            1437
       case .upArrow:
            1438
       case .upRightArrow:
            1439
       case .rightArrow:
            1440
       case .downRightArrow:
            1441
       case .downArrow:
            1442
       case .downLeftArrow:
            1443
       case .leftArrow:
            1444
       case .upLeftArrow:
            1445
       case .upDownArrow:
            1446
       case .leftRightArrow:
            1447
       case .rightArrowCurvingLeft:
            1448
       case .leftArrowCurvingRight:
            1449
       case .rightArrowCurvingUp:
            1450
       case .rightArrowCurvingDown:
            1451
       case .clockwiseVerticalArrows:
            1452
       case .counterclockwiseArrowsButton:
            1453
       case .backArrow:
            1454
       case .endArrow:
            1455
       case .onArrow:
            1456
       case .soonArrow:
            1457
       case .topArrow:
            1458
       case .placeOfWorship:
            1459
       case .atomSymbol:
            1460
       case .om:
            1461
       case .starOfDavid:
            1462
       case .wheelOfDharma:
            1463
       case .yinYang:
            1464
       case .latinCross:
            1465
       case .orthodoxCross:
            1466
       case .starAndCrescent:
            1467
       case .peaceSymbol:
            1468
       case .menorah:
            1469
       case .dottedSixPointedStar:
            1470
       case .khanda:
            1471
       case .aries:
            1472
       case .taurus:
            1473
       case .gemini:
            1474
       case .cancer:
            1475
       case .leo:
            1476
       case .virgo:
            1477
       case .libra:
            1478
       case .scorpio:
            1479
       case .sagittarius:
            1480
       case .capricorn:
            1481
       case .aquarius:
            1482
       case .pisces:
            1483
       case .ophiuchus:
            1484
       case .shuffleTracksButton:
            1485
       case .repeatButton:
            1486
       case .repeatSingleButton:
            1487
       case .playButton:
            1488
       case .fastForwardButton:
            1489
       case .nextTrackButton:
            1490
       case .playOrPauseButton:
            1491
       case .reverseButton:
            1492
       case .fastReverseButton:
            1493
       case .lastTrackButton:
            1494
       case .upwardsButton:
            1495
       case .fastUpButton:
            1496
       case .downwardsButton:
            1497
       case .fastDownButton:
            1498
       case .pauseButton:
            1499
       case .stopButton:
            1500
       case .recordButton:
            1501
       case .ejectButton:
            1502
       case .cinema:
            1503
       case .dimButton:
            1504
       case .brightButton:
            1505
       case .antennaBars:
            1506
       case .wireless:
            1507
       case .vibrationMode:
            1508
       case .mobilePhoneOff:
            1509
       case .femaleSign:
            1510
       case .maleSign:
            1511
       case .transgenderSymbol:
            1512
       case .multiply:
            1513
       case .plus:
            1514
       case .minus:
            1515
       case .divide:
            1516
       case .heavyEqualsSign:
            1517
       case .infinity:
            1518
       case .doubleExclamationMark:
            1519
       case .exclamationQuestionMark:
            1520
       case .redQuestionMark:
            1521
       case .whiteQuestionMark:
            1522
       case .whiteExclamationMark:
            1523
       case .redExclamationMark:
            1524
       case .wavyDash:
            1525
       case .currencyExchange:
            1526
       case .heavyDollarSign:
            1527
       case .medicalSymbol:
            1528
       case .recyclingSymbol:
            1529
       case .fleurDeLis:
            1530
       case .tridentEmblem:
            1531
       case .nameBadge:
            1532
       case .japaneseSymbolForBeginner:
            1533
       case .hollowRedCircle:
            1534
       case .checkMarkButton:
            1535
       case .checkBoxWithCheck:
            1536
       case .checkMark:
            1537
       case .crossMark:
            1538
       case .crossMarkButton:
            1539
       case .curlyLoop:
            1540
       case .doubleCurlyLoop:
            1541
       case .partAlternationMark:
            1542
       case .eightSpokedAsterisk:
            1543
       case .eightPointedStar:
            1544
       case .sparkle:
            1545
       case .copyright:
            1546
       case .registered:
            1547
       case .tradeMark:
            1548
       case .splatter:
            1549
       case .keycapRoute:
            1550
       case .keycapStar:
            1551
       case .keycap0:
            1552
       case .keycap1:
            1553
       case .keycap2:
            1554
       case .keycap3:
            1555
       case .keycap4:
            1556
       case .keycap5:
            1557
       case .keycap6:
            1558
       case .keycap7:
            1559
       case .keycap8:
            1560
       case .keycap9:
            1561
       case .keycap10:
            1562
       case .inputLatinUppercase:
            1563
       case .inputLatinLowercase:
            1564
       case .inputNumbers:
            1565
       case .inputSymbols:
            1566
       case .inputLatinLetters:
            1567
       case .aButtonBloodType:
            1568
       case .abButtonBloodType:
            1569
       case .bButtonBloodType:
            1570
       case .clButton:
            1571
       case .coolButton:
            1572
       case .freeButton:
            1573
       case .information:
            1574
       case .idButton:
            1575
       case .circledM:
            1576
       case .newButton:
            1577
       case .ngButton:
            1578
       case .oButtonBloodType:
            1579
       case .okButton:
            1580
       case .pButton:
            1581
       case .sosButton:
            1582
       case .upButton:
            1583
       case .vsButton:
            1584
       case .japaneseHereButton:
            1585
       case .japaneseServiceChargeButton:
            1586
       case .japaneseMonthlyAmountButton:
            1587
       case .japaneseNotFreeOfChargeButton:
            1588
       case .japaneseReservedButton:
            1589
       case .japaneseBargainButton:
            1590
       case .japaneseDiscountButton:
            1591
       case .japaneseFreeOfChargeButton:
            1592
       case .japaneseProhibitedButton:
            1593
       case .japaneseAcceptableButton:
            1594
       case .japaneseApplicationButton:
            1595
       case .japanesePassingGradeButton:
            1596
       case .japaneseVacancyButton:
            1597
       case .japaneseCongratulationsButton:
            1598
       case .japaneseSecretButton:
            1599
       case .japaneseOpenForBusinessButton:
            1600
       case .japaneseNoVacancyButton:
            1601
       case .redCircle:
            1602
       case .orangeCircle:
            1603
       case .yellowCircle:
            1604
       case .greenCircle:
            1605
       case .blueCircle:
            1606
       case .purpleCircle:
            1607
       case .brownCircle:
            1608
       case .blackCircle:
            1609
       case .whiteCircle:
            1610
       case .redSquare:
            1611
       case .orangeSquare:
            1612
       case .yellowSquare:
            1613
       case .greenSquare:
            1614
       case .blueSquare:
            1615
       case .purpleSquare:
            1616
       case .brownSquare:
            1617
       case .blackLargeSquare:
            1618
       case .whiteLargeSquare:
            1619
       case .blackMediumSquare:
            1620
       case .whiteMediumSquare:
            1621
       case .blackMediumSmallSquare:
            1622
       case .whiteMediumSmallSquare:
            1623
       case .blackSmallSquare:
            1624
       case .whiteSmallSquare:
            1625
       case .largeOrangeDiamond:
            1626
       case .largeBlueDiamond:
            1627
       case .smallOrangeDiamond:
            1628
       case .smallBlueDiamond:
            1629
       case .redTrianglePointedUp:
            1630
       case .redTrianglePointedDown:
            1631
       case .diamondWithADot:
            1632
       case .radioButton:
            1633
       case .whiteSquareButton:
            1634
       case .blackSquareButton:
            1635
       case .chequeredFlag:
            1636
       case .triangularFlag:
            1637
       case .crossedFlags:
            1638
       case .blackFlag:
            1639
       case .whiteFlag:
            1640
       case .rainbowFlag:
            1641
       case .transgenderFlag:
            1642
       case .pirateFlag:
            1643
       case .flagAscensionIsland:
            1644
       case .flagAndorra:
            1645
       case .flagUnitedArabEmirates:
            1646
       case .flagAfghanistan:
            1647
       case .flagAntiguaBarbuda:
            1648
       case .flagAnguilla:
            1649
       case .flagAlbania:
            1650
       case .flagArmenia:
            1651
       case .flagAngola:
            1652
       case .flagAntarctica:
            1653
       case .flagArgentina:
            1654
       case .flagAmericanSamoa:
            1655
       case .flagAustria:
            1656
       case .flagAustralia:
            1657
       case .flagAruba:
            1658
       case .flagAlandIslands:
            1659
       case .flagAzerbaijan:
            1660
       case .flagBosniaHerzegovina:
            1661
       case .flagBarbados:
            1662
       case .flagBangladesh:
            1663
       case .flagBelgium:
            1664
       case .flagBurkinaFaso:
            1665
       case .flagBulgaria:
            1666
       case .flagBahrain:
            1667
       case .flagBurundi:
            1668
       case .flagBenin:
            1669
       case .flagStBarthelemy:
            1670
       case .flagBermuda:
            1671
       case .flagBrunei:
            1672
       case .flagBolivia:
            1673
       case .flagCaribbeanNetherlands:
            1674
       case .flagBrazil:
            1675
       case .flagBahamas:
            1676
       case .flagBhutan:
            1677
       case .flagBouvetIsland:
            1678
       case .flagBotswana:
            1679
       case .flagBelarus:
            1680
       case .flagBelize:
            1681
       case .flagCanada:
            1682
       case .flagCocosKeelingIslands:
            1683
       case .flagCongoKinshasa:
            1684
       case .flagCentralAfricanRepublic:
            1685
       case .flagCongoBrazzaville:
            1686
       case .flagSwitzerland:
            1687
       case .flagCoteDIvoire:
            1688
       case .flagCookIslands:
            1689
       case .flagChile:
            1690
       case .flagCameroon:
            1691
       case .flagChina:
            1692
       case .flagColombia:
            1693
       case .flagClippertonIsland:
            1694
       case .flagSark:
            1695
       case .flagCostaRica:
            1696
       case .flagCuba:
            1697
       case .flagCapeVerde:
            1698
       case .flagCuracao:
            1699
       case .flagChristmasIsland:
            1700
       case .flagCyprus:
            1701
       case .flagCzechia:
            1702
       case .flagGermany:
            1703
       case .flagDiegoGarcia:
            1704
       case .flagDjibouti:
            1705
       case .flagDenmark:
            1706
       case .flagDominica:
            1707
       case .flagDominicanRepublic:
            1708
       case .flagAlgeria:
            1709
       case .flagCeutaMelilla:
            1710
       case .flagEcuador:
            1711
       case .flagEstonia:
            1712
       case .flagEgypt:
            1713
       case .flagWesternSahara:
            1714
       case .flagEritrea:
            1715
       case .flagSpain:
            1716
       case .flagEthiopia:
            1717
       case .flagEuropeanUnion:
            1718
       case .flagFinland:
            1719
       case .flagFiji:
            1720
       case .flagFalklandIslands:
            1721
       case .flagMicronesia:
            1722
       case .flagFaroeIslands:
            1723
       case .flagFrance:
            1724
       case .flagGabon:
            1725
       case .flagUnitedKingdom:
            1726
       case .flagGrenada:
            1727
       case .flagGeorgia:
            1728
       case .flagFrenchGuiana:
            1729
       case .flagGuernsey:
            1730
       case .flagGhana:
            1731
       case .flagGibraltar:
            1732
       case .flagGreenland:
            1733
       case .flagGambia:
            1734
       case .flagGuinea:
            1735
       case .flagGuadeloupe:
            1736
       case .flagEquatorialGuinea:
            1737
       case .flagGreece:
            1738
       case .flagSouthGeorgiaSouthSandwichIslands:
            1739
       case .flagGuatemala:
            1740
       case .flagGuam:
            1741
       case .flagGuineaBissau:
            1742
       case .flagGuyana:
            1743
       case .flagHongKongSarChina:
            1744
       case .flagHeardMcdonaldIslands:
            1745
       case .flagHonduras:
            1746
       case .flagCroatia:
            1747
       case .flagHaiti:
            1748
       case .flagHungary:
            1749
       case .flagCanaryIslands:
            1750
       case .flagIndonesia:
            1751
       case .flagIreland:
            1752
       case .flagIsrael:
            1753
       case .flagIsleOfMan:
            1754
       case .flagIndia:
            1755
       case .flagBritishIndianOceanTerritory:
            1756
       case .flagIraq:
            1757
       case .flagIran:
            1758
       case .flagIceland:
            1759
       case .flagItaly:
            1760
       case .flagJersey:
            1761
       case .flagJamaica:
            1762
       case .flagJordan:
            1763
       case .flagJapan:
            1764
       case .flagKenya:
            1765
       case .flagKyrgyzstan:
            1766
       case .flagCambodia:
            1767
       case .flagKiribati:
            1768
       case .flagComoros:
            1769
       case .flagStKittsNevis:
            1770
       case .flagNorthKorea:
            1771
       case .flagSouthKorea:
            1772
       case .flagKuwait:
            1773
       case .flagCaymanIslands:
            1774
       case .flagKazakhstan:
            1775
       case .flagLaos:
            1776
       case .flagLebanon:
            1777
       case .flagStLucia:
            1778
       case .flagLiechtenstein:
            1779
       case .flagSriLanka:
            1780
       case .flagLiberia:
            1781
       case .flagLesotho:
            1782
       case .flagLithuania:
            1783
       case .flagLuxembourg:
            1784
       case .flagLatvia:
            1785
       case .flagLibya:
            1786
       case .flagMorocco:
            1787
       case .flagMonaco:
            1788
       case .flagMoldova:
            1789
       case .flagMontenegro:
            1790
       case .flagStMartin:
            1791
       case .flagMadagascar:
            1792
       case .flagMarshallIslands:
            1793
       case .flagNorthMacedonia:
            1794
       case .flagMali:
            1795
       case .flagMyanmarBurma:
            1796
       case .flagMongolia:
            1797
       case .flagMacaoSarChina:
            1798
       case .flagNorthernMarianaIslands:
            1799
       case .flagMartinique:
            1800
       case .flagMauritania:
            1801
       case .flagMontserrat:
            1802
       case .flagMalta:
            1803
       case .flagMauritius:
            1804
       case .flagMaldives:
            1805
       case .flagMalawi:
            1806
       case .flagMexico:
            1807
       case .flagMalaysia:
            1808
       case .flagMozambique:
            1809
       case .flagNamibia:
            1810
       case .flagNewCaledonia:
            1811
       case .flagNiger:
            1812
       case .flagNorfolkIsland:
            1813
       case .flagNigeria:
            1814
       case .flagNicaragua:
            1815
       case .flagNetherlands:
            1816
       case .flagNorway:
            1817
       case .flagNepal:
            1818
       case .flagNauru:
            1819
       case .flagNiue:
            1820
       case .flagNewZealand:
            1821
       case .flagOman:
            1822
       case .flagPanama:
            1823
       case .flagPeru:
            1824
       case .flagFrenchPolynesia:
            1825
       case .flagPapuaNewGuinea:
            1826
       case .flagPhilippines:
            1827
       case .flagPakistan:
            1828
       case .flagPoland:
            1829
       case .flagStPierreMiquelon:
            1830
       case .flagPitcairnIslands:
            1831
       case .flagPuertoRico:
            1832
       case .flagPalestinianTerritories:
            1833
       case .flagPortugal:
            1834
       case .flagPalau:
            1835
       case .flagParaguay:
            1836
       case .flagQatar:
            1837
       case .flagReunion:
            1838
       case .flagRomania:
            1839
       case .flagSerbia:
            1840
       case .flagRussia:
            1841
       case .flagRwanda:
            1842
       case .flagSaudiArabia:
            1843
       case .flagSolomonIslands:
            1844
       case .flagSeychelles:
            1845
       case .flagSudan:
            1846
       case .flagSweden:
            1847
       case .flagSingapore:
            1848
       case .flagStHelena:
            1849
       case .flagSlovenia:
            1850
       case .flagSvalbardJanMayen:
            1851
       case .flagSlovakia:
            1852
       case .flagSierraLeone:
            1853
       case .flagSanMarino:
            1854
       case .flagSenegal:
            1855
       case .flagSomalia:
            1856
       case .flagSuriname:
            1857
       case .flagSouthSudan:
            1858
       case .flagSaoTomePrincipe:
            1859
       case .flagElSalvador:
            1860
       case .flagSintMaarten:
            1861
       case .flagSyria:
            1862
       case .flagEswatini:
            1863
       case .flagTristanDaCunha:
            1864
       case .flagTurksCaicosIslands:
            1865
       case .flagChad:
            1866
       case .flagFrenchSouthernTerritories:
            1867
       case .flagTogo:
            1868
       case .flagThailand:
            1869
       case .flagTajikistan:
            1870
       case .flagTokelau:
            1871
       case .flagTimorLeste:
            1872
       case .flagTurkmenistan:
            1873
       case .flagTunisia:
            1874
       case .flagTonga:
            1875
       case .flagTurkiye:
            1876
       case .flagTrinidadTobago:
            1877
       case .flagTuvalu:
            1878
       case .flagTaiwan:
            1879
       case .flagTanzania:
            1880
       case .flagUkraine:
            1881
       case .flagUganda:
            1882
       case .flagUSOutlyingIslands:
            1883
       case .flagUnitedNations:
            1884
       case .flagUnitedStates:
            1885
       case .flagUruguay:
            1886
       case .flagUzbekistan:
            1887
       case .flagVaticanCity:
            1888
       case .flagStVincentGrenadines:
            1889
       case .flagVenezuela:
            1890
       case .flagBritishVirginIslands:
            1891
       case .flagUSVirginIslands:
            1892
       case .flagVietnam:
            1893
       case .flagVanuatu:
            1894
       case .flagWallisFutuna:
            1895
       case .flagSamoa:
            1896
       case .flagKosovo:
            1897
       case .flagYemen:
            1898
       case .flagMayotte:
            1899
       case .flagSouthAfrica:
            1900
       case .flagZambia:
            1901
       case .flagZimbabwe:
            1902
       case .flagEngland:
            1903
       case .flagScotland:
            1904
       case .flagWales:
            1905
        }
    }

    public enum SkinTone: String, CaseIterable, Equatable {
        case light, mediumLight, medium, mediumDark, dark
    }

    public static var allVariants: [Emoji:[[SkinTone]:String]] = {
        [
            .wavingHand:[
                [.light]: "👋🏻",
                [.mediumLight]: "👋🏼",
                [.medium]: "👋🏽",
                [.mediumDark]: "👋🏾",
                [.dark]: "👋🏿"
            ],
            .raisedBackOfHand:[
                [.light]: "🤚🏻",
                [.mediumLight]: "🤚🏼",
                [.medium]: "🤚🏽",
                [.mediumDark]: "🤚🏾",
                [.dark]: "🤚🏿"
            ],
            .handWithFingersSplayed:[
                [.light]: "🖐🏻",
                [.mediumLight]: "🖐🏼",
                [.medium]: "🖐🏽",
                [.mediumDark]: "🖐🏾",
                [.dark]: "🖐🏿"
            ],
            .raisedHand:[
                [.light]: "✋🏻",
                [.mediumLight]: "✋🏼",
                [.medium]: "✋🏽",
                [.mediumDark]: "✋🏾",
                [.dark]: "✋🏿"
            ],
            .vulcanSalute:[
                [.light]: "🖖🏻",
                [.mediumLight]: "🖖🏼",
                [.medium]: "🖖🏽",
                [.mediumDark]: "🖖🏾",
                [.dark]: "🖖🏿"
            ],
            .rightwardsHand:[
                [.light]: "🫱🏻",
                [.mediumLight]: "🫱🏼",
                [.medium]: "🫱🏽",
                [.mediumDark]: "🫱🏾",
                [.dark]: "🫱🏿"
            ],
            .leftwardsHand:[
                [.light]: "🫲🏻",
                [.mediumLight]: "🫲🏼",
                [.medium]: "🫲🏽",
                [.mediumDark]: "🫲🏾",
                [.dark]: "🫲🏿"
            ],
            .palmDownHand:[
                [.light]: "🫳🏻",
                [.mediumLight]: "🫳🏼",
                [.medium]: "🫳🏽",
                [.mediumDark]: "🫳🏾",
                [.dark]: "🫳🏿"
            ],
            .palmUpHand:[
                [.light]: "🫴🏻",
                [.mediumLight]: "🫴🏼",
                [.medium]: "🫴🏽",
                [.mediumDark]: "🫴🏾",
                [.dark]: "🫴🏿"
            ],
            .leftwardsPushingHand:[
                [.light]: "🫷🏻",
                [.mediumLight]: "🫷🏼",
                [.medium]: "🫷🏽",
                [.mediumDark]: "🫷🏾",
                [.dark]: "🫷🏿"
            ],
            .rightwardsPushingHand:[
                [.light]: "🫸🏻",
                [.mediumLight]: "🫸🏼",
                [.medium]: "🫸🏽",
                [.mediumDark]: "🫸🏾",
                [.dark]: "🫸🏿"
            ],
            .okHand:[
                [.light]: "👌🏻",
                [.mediumLight]: "👌🏼",
                [.medium]: "👌🏽",
                [.mediumDark]: "👌🏾",
                [.dark]: "👌🏿"
            ],
            .pinchedFingers:[
                [.light]: "🤌🏻",
                [.mediumLight]: "🤌🏼",
                [.medium]: "🤌🏽",
                [.mediumDark]: "🤌🏾",
                [.dark]: "🤌🏿"
            ],
            .pinchingHand:[
                [.light]: "🤏🏻",
                [.mediumLight]: "🤏🏼",
                [.medium]: "🤏🏽",
                [.mediumDark]: "🤏🏾",
                [.dark]: "🤏🏿"
            ],
            .victoryHand:[
                [.light]: "✌🏻",
                [.mediumLight]: "✌🏼",
                [.medium]: "✌🏽",
                [.mediumDark]: "✌🏾",
                [.dark]: "✌🏿"
            ],
            .crossedFingers:[
                [.light]: "🤞🏻",
                [.mediumLight]: "🤞🏼",
                [.medium]: "🤞🏽",
                [.mediumDark]: "🤞🏾",
                [.dark]: "🤞🏿"
            ],
            .handWithIndexFingerAndThumbCrossed:[
                [.light]: "🫰🏻",
                [.mediumLight]: "🫰🏼",
                [.medium]: "🫰🏽",
                [.mediumDark]: "🫰🏾",
                [.dark]: "🫰🏿"
            ],
            .loveYouGesture:[
                [.light]: "🤟🏻",
                [.mediumLight]: "🤟🏼",
                [.medium]: "🤟🏽",
                [.mediumDark]: "🤟🏾",
                [.dark]: "🤟🏿"
            ],
            .signOfTheHorns:[
                [.light]: "🤘🏻",
                [.mediumLight]: "🤘🏼",
                [.medium]: "🤘🏽",
                [.mediumDark]: "🤘🏾",
                [.dark]: "🤘🏿"
            ],
            .callMeHand:[
                [.light]: "🤙🏻",
                [.mediumLight]: "🤙🏼",
                [.medium]: "🤙🏽",
                [.mediumDark]: "🤙🏾",
                [.dark]: "🤙🏿"
            ],
            .backhandIndexPointingLeft:[
                [.light]: "👈🏻",
                [.mediumLight]: "👈🏼",
                [.medium]: "👈🏽",
                [.mediumDark]: "👈🏾",
                [.dark]: "👈🏿"
            ],
            .backhandIndexPointingRight:[
                [.light]: "👉🏻",
                [.mediumLight]: "👉🏼",
                [.medium]: "👉🏽",
                [.mediumDark]: "👉🏾",
                [.dark]: "👉🏿"
            ],
            .backhandIndexPointingUp:[
                [.light]: "👆🏻",
                [.mediumLight]: "👆🏼",
                [.medium]: "👆🏽",
                [.mediumDark]: "👆🏾",
                [.dark]: "👆🏿"
            ],
            .middleFinger:[
                [.light]: "🖕🏻",
                [.mediumLight]: "🖕🏼",
                [.medium]: "🖕🏽",
                [.mediumDark]: "🖕🏾",
                [.dark]: "🖕🏿"
            ],
            .backhandIndexPointingDown:[
                [.light]: "👇🏻",
                [.mediumLight]: "👇🏼",
                [.medium]: "👇🏽",
                [.mediumDark]: "👇🏾",
                [.dark]: "👇🏿"
            ],
            .indexPointingUp:[
                [.light]: "☝🏻",
                [.mediumLight]: "☝🏼",
                [.medium]: "☝🏽",
                [.mediumDark]: "☝🏾",
                [.dark]: "☝🏿"
            ],
            .indexPointingAtTheViewer:[
                [.light]: "🫵🏻",
                [.mediumLight]: "🫵🏼",
                [.medium]: "🫵🏽",
                [.mediumDark]: "🫵🏾",
                [.dark]: "🫵🏿"
            ],
            .thumbsUp:[
                [.light]: "👍🏻",
                [.mediumLight]: "👍🏼",
                [.medium]: "👍🏽",
                [.mediumDark]: "👍🏾",
                [.dark]: "👍🏿"
            ],
            .thumbsDown:[
                [.light]: "👎🏻",
                [.mediumLight]: "👎🏼",
                [.medium]: "👎🏽",
                [.mediumDark]: "👎🏾",
                [.dark]: "👎🏿"
            ],
            .raisedFist:[
                [.light]: "✊🏻",
                [.mediumLight]: "✊🏼",
                [.medium]: "✊🏽",
                [.mediumDark]: "✊🏾",
                [.dark]: "✊🏿"
            ],
            .oncomingFist:[
                [.light]: "👊🏻",
                [.mediumLight]: "👊🏼",
                [.medium]: "👊🏽",
                [.mediumDark]: "👊🏾",
                [.dark]: "👊🏿"
            ],
            .leftFacingFist:[
                [.light]: "🤛🏻",
                [.mediumLight]: "🤛🏼",
                [.medium]: "🤛🏽",
                [.mediumDark]: "🤛🏾",
                [.dark]: "🤛🏿"
            ],
            .rightFacingFist:[
                [.light]: "🤜🏻",
                [.mediumLight]: "🤜🏼",
                [.medium]: "🤜🏽",
                [.mediumDark]: "🤜🏾",
                [.dark]: "🤜🏿"
            ],
            .clappingHands:[
                [.light]: "👏🏻",
                [.mediumLight]: "👏🏼",
                [.medium]: "👏🏽",
                [.mediumDark]: "👏🏾",
                [.dark]: "👏🏿"
            ],
            .raisingHands:[
                [.light]: "🙌🏻",
                [.mediumLight]: "🙌🏼",
                [.medium]: "🙌🏽",
                [.mediumDark]: "🙌🏾",
                [.dark]: "🙌🏿"
            ],
            .heartHands:[
                [.light]: "🫶🏻",
                [.mediumLight]: "🫶🏼",
                [.medium]: "🫶🏽",
                [.mediumDark]: "🫶🏾",
                [.dark]: "🫶🏿"
            ],
            .openHands:[
                [.light]: "👐🏻",
                [.mediumLight]: "👐🏼",
                [.medium]: "👐🏽",
                [.mediumDark]: "👐🏾",
                [.dark]: "👐🏿"
            ],
            .palmsUpTogether:[
                [.light]: "🤲🏻",
                [.mediumLight]: "🤲🏼",
                [.medium]: "🤲🏽",
                [.mediumDark]: "🤲🏾",
                [.dark]: "🤲🏿"
            ],
            .handshake:[
                [.light]: "🤝🏻",
                [.mediumLight]: "🤝🏼",
                [.medium]: "🤝🏽",
                [.mediumDark]: "🤝🏾",
                [.dark]: "🤝🏿",
                [.light, .mediumLight]: "🫱🏻‍🫲🏼",
                [.light, .medium]: "🫱🏻‍🫲🏽",
                [.light, .mediumDark]: "🫱🏻‍🫲🏾",
                [.light, .dark]: "🫱🏻‍🫲🏿",
                [.mediumLight, .light]: "🫱🏼‍🫲🏻",
                [.mediumLight, .medium]: "🫱🏼‍🫲🏽",
                [.mediumLight, .mediumDark]: "🫱🏼‍🫲🏾",
                [.mediumLight, .dark]: "🫱🏼‍🫲🏿",
                [.medium, .light]: "🫱🏽‍🫲🏻",
                [.medium, .mediumLight]: "🫱🏽‍🫲🏼",
                [.medium, .mediumDark]: "🫱🏽‍🫲🏾",
                [.medium, .dark]: "🫱🏽‍🫲🏿",
                [.mediumDark, .light]: "🫱🏾‍🫲🏻",
                [.mediumDark, .mediumLight]: "🫱🏾‍🫲🏼",
                [.mediumDark, .medium]: "🫱🏾‍🫲🏽",
                [.mediumDark, .dark]: "🫱🏾‍🫲🏿",
                [.dark, .light]: "🫱🏿‍🫲🏻",
                [.dark, .mediumLight]: "🫱🏿‍🫲🏼",
                [.dark, .medium]: "🫱🏿‍🫲🏽",
                [.dark, .mediumDark]: "🫱🏿‍🫲🏾"
            ],
            .foldedHands:[
                [.light]: "🙏🏻",
                [.mediumLight]: "🙏🏼",
                [.medium]: "🙏🏽",
                [.mediumDark]: "🙏🏾",
                [.dark]: "🙏🏿"
            ],
            .writingHand:[
                [.light]: "✍🏻",
                [.mediumLight]: "✍🏼",
                [.medium]: "✍🏽",
                [.mediumDark]: "✍🏾",
                [.dark]: "✍🏿"
            ],
            .nailPolish:[
                [.light]: "💅🏻",
                [.mediumLight]: "💅🏼",
                [.medium]: "💅🏽",
                [.mediumDark]: "💅🏾",
                [.dark]: "💅🏿"
            ],
            .selfie:[
                [.light]: "🤳🏻",
                [.mediumLight]: "🤳🏼",
                [.medium]: "🤳🏽",
                [.mediumDark]: "🤳🏾",
                [.dark]: "🤳🏿"
            ],
            .flexedBiceps:[
                [.light]: "💪🏻",
                [.mediumLight]: "💪🏼",
                [.medium]: "💪🏽",
                [.mediumDark]: "💪🏾",
                [.dark]: "💪🏿"
            ],
            .leg:[
                [.light]: "🦵🏻",
                [.mediumLight]: "🦵🏼",
                [.medium]: "🦵🏽",
                [.mediumDark]: "🦵🏾",
                [.dark]: "🦵🏿"
            ],
            .foot:[
                [.light]: "🦶🏻",
                [.mediumLight]: "🦶🏼",
                [.medium]: "🦶🏽",
                [.mediumDark]: "🦶🏾",
                [.dark]: "🦶🏿"
            ],
            .ear:[
                [.light]: "👂🏻",
                [.mediumLight]: "👂🏼",
                [.medium]: "👂🏽",
                [.mediumDark]: "👂🏾",
                [.dark]: "👂🏿"
            ],
            .earWithHearingAid:[
                [.light]: "🦻🏻",
                [.mediumLight]: "🦻🏼",
                [.medium]: "🦻🏽",
                [.mediumDark]: "🦻🏾",
                [.dark]: "🦻🏿"
            ],
            .nose:[
                [.light]: "👃🏻",
                [.mediumLight]: "👃🏼",
                [.medium]: "👃🏽",
                [.mediumDark]: "👃🏾",
                [.dark]: "👃🏿"
            ],
            .baby:[
                [.light]: "👶🏻",
                [.mediumLight]: "👶🏼",
                [.medium]: "👶🏽",
                [.mediumDark]: "👶🏾",
                [.dark]: "👶🏿"
            ],
            .child:[
                [.light]: "🧒🏻",
                [.mediumLight]: "🧒🏼",
                [.medium]: "🧒🏽",
                [.mediumDark]: "🧒🏾",
                [.dark]: "🧒🏿"
            ],
            .boy:[
                [.light]: "👦🏻",
                [.mediumLight]: "👦🏼",
                [.medium]: "👦🏽",
                [.mediumDark]: "👦🏾",
                [.dark]: "👦🏿"
            ],
            .girl:[
                [.light]: "👧🏻",
                [.mediumLight]: "👧🏼",
                [.medium]: "👧🏽",
                [.mediumDark]: "👧🏾",
                [.dark]: "👧🏿"
            ],
            .person:[
                [.light]: "🧑🏻",
                [.mediumLight]: "🧑🏼",
                [.medium]: "🧑🏽",
                [.mediumDark]: "🧑🏾",
                [.dark]: "🧑🏿"
            ],
            .personBlondHair:[
                [.light]: "👱🏻",
                [.mediumLight]: "👱🏼",
                [.medium]: "👱🏽",
                [.mediumDark]: "👱🏾",
                [.dark]: "👱🏿"
            ],
            .man:[
                [.light]: "👨🏻",
                [.mediumLight]: "👨🏼",
                [.medium]: "👨🏽",
                [.mediumDark]: "👨🏾",
                [.dark]: "👨🏿"
            ],
            .personBeard:[
                [.light]: "🧔🏻",
                [.mediumLight]: "🧔🏼",
                [.medium]: "🧔🏽",
                [.mediumDark]: "🧔🏾",
                [.dark]: "🧔🏿"
            ],
            .manBeard:[
                [.light]: "🧔🏻‍♂️",
                [.mediumLight]: "🧔🏼‍♂️",
                [.medium]: "🧔🏽‍♂️",
                [.mediumDark]: "🧔🏾‍♂️",
                [.dark]: "🧔🏿‍♂️"
            ],
            .womanBeard:[
                [.light]: "🧔🏻‍♀️",
                [.mediumLight]: "🧔🏼‍♀️",
                [.medium]: "🧔🏽‍♀️",
                [.mediumDark]: "🧔🏾‍♀️",
                [.dark]: "🧔🏿‍♀️"
            ],
            .manRedHair:[
                [.light]: "👨🏻‍🦰",
                [.mediumLight]: "👨🏼‍🦰",
                [.medium]: "👨🏽‍🦰",
                [.mediumDark]: "👨🏾‍🦰",
                [.dark]: "👨🏿‍🦰"
            ],
            .manCurlyHair:[
                [.light]: "👨🏻‍🦱",
                [.mediumLight]: "👨🏼‍🦱",
                [.medium]: "👨🏽‍🦱",
                [.mediumDark]: "👨🏾‍🦱",
                [.dark]: "👨🏿‍🦱"
            ],
            .manWhiteHair:[
                [.light]: "👨🏻‍🦳",
                [.mediumLight]: "👨🏼‍🦳",
                [.medium]: "👨🏽‍🦳",
                [.mediumDark]: "👨🏾‍🦳",
                [.dark]: "👨🏿‍🦳"
            ],
            .manBald:[
                [.light]: "👨🏻‍🦲",
                [.mediumLight]: "👨🏼‍🦲",
                [.medium]: "👨🏽‍🦲",
                [.mediumDark]: "👨🏾‍🦲",
                [.dark]: "👨🏿‍🦲"
            ],
            .woman:[
                [.light]: "👩🏻",
                [.mediumLight]: "👩🏼",
                [.medium]: "👩🏽",
                [.mediumDark]: "👩🏾",
                [.dark]: "👩🏿"
            ],
            .womanRedHair:[
                [.light]: "👩🏻‍🦰",
                [.mediumLight]: "👩🏼‍🦰",
                [.medium]: "👩🏽‍🦰",
                [.mediumDark]: "👩🏾‍🦰",
                [.dark]: "👩🏿‍🦰"
            ],
            .personRedHair:[
                [.light]: "🧑🏻‍🦰",
                [.mediumLight]: "🧑🏼‍🦰",
                [.medium]: "🧑🏽‍🦰",
                [.mediumDark]: "🧑🏾‍🦰",
                [.dark]: "🧑🏿‍🦰"
            ],
            .womanCurlyHair:[
                [.light]: "👩🏻‍🦱",
                [.mediumLight]: "👩🏼‍🦱",
                [.medium]: "👩🏽‍🦱",
                [.mediumDark]: "👩🏾‍🦱",
                [.dark]: "👩🏿‍🦱"
            ],
            .personCurlyHair:[
                [.light]: "🧑🏻‍🦱",
                [.mediumLight]: "🧑🏼‍🦱",
                [.medium]: "🧑🏽‍🦱",
                [.mediumDark]: "🧑🏾‍🦱",
                [.dark]: "🧑🏿‍🦱"
            ],
            .womanWhiteHair:[
                [.light]: "👩🏻‍🦳",
                [.mediumLight]: "👩🏼‍🦳",
                [.medium]: "👩🏽‍🦳",
                [.mediumDark]: "👩🏾‍🦳",
                [.dark]: "👩🏿‍🦳"
            ],
            .personWhiteHair:[
                [.light]: "🧑🏻‍🦳",
                [.mediumLight]: "🧑🏼‍🦳",
                [.medium]: "🧑🏽‍🦳",
                [.mediumDark]: "🧑🏾‍🦳",
                [.dark]: "🧑🏿‍🦳"
            ],
            .womanBald:[
                [.light]: "👩🏻‍🦲",
                [.mediumLight]: "👩🏼‍🦲",
                [.medium]: "👩🏽‍🦲",
                [.mediumDark]: "👩🏾‍🦲",
                [.dark]: "👩🏿‍🦲"
            ],
            .personBald:[
                [.light]: "🧑🏻‍🦲",
                [.mediumLight]: "🧑🏼‍🦲",
                [.medium]: "🧑🏽‍🦲",
                [.mediumDark]: "🧑🏾‍🦲",
                [.dark]: "🧑🏿‍🦲"
            ],
            .womanBlondHair:[
                [.light]: "👱🏻‍♀️",
                [.mediumLight]: "👱🏼‍♀️",
                [.medium]: "👱🏽‍♀️",
                [.mediumDark]: "👱🏾‍♀️",
                [.dark]: "👱🏿‍♀️"
            ],
            .manBlondHair:[
                [.light]: "👱🏻‍♂️",
                [.mediumLight]: "👱🏼‍♂️",
                [.medium]: "👱🏽‍♂️",
                [.mediumDark]: "👱🏾‍♂️",
                [.dark]: "👱🏿‍♂️"
            ],
            .olderPerson:[
                [.light]: "🧓🏻",
                [.mediumLight]: "🧓🏼",
                [.medium]: "🧓🏽",
                [.mediumDark]: "🧓🏾",
                [.dark]: "🧓🏿"
            ],
            .oldMan:[
                [.light]: "👴🏻",
                [.mediumLight]: "👴🏼",
                [.medium]: "👴🏽",
                [.mediumDark]: "👴🏾",
                [.dark]: "👴🏿"
            ],
            .oldWoman:[
                [.light]: "👵🏻",
                [.mediumLight]: "👵🏼",
                [.medium]: "👵🏽",
                [.mediumDark]: "👵🏾",
                [.dark]: "👵🏿"
            ],
            .personFrowning:[
                [.light]: "🙍🏻",
                [.mediumLight]: "🙍🏼",
                [.medium]: "🙍🏽",
                [.mediumDark]: "🙍🏾",
                [.dark]: "🙍🏿"
            ],
            .manFrowning:[
                [.light]: "🙍🏻‍♂️",
                [.mediumLight]: "🙍🏼‍♂️",
                [.medium]: "🙍🏽‍♂️",
                [.mediumDark]: "🙍🏾‍♂️",
                [.dark]: "🙍🏿‍♂️"
            ],
            .womanFrowning:[
                [.light]: "🙍🏻‍♀️",
                [.mediumLight]: "🙍🏼‍♀️",
                [.medium]: "🙍🏽‍♀️",
                [.mediumDark]: "🙍🏾‍♀️",
                [.dark]: "🙍🏿‍♀️"
            ],
            .personPouting:[
                [.light]: "🙎🏻",
                [.mediumLight]: "🙎🏼",
                [.medium]: "🙎🏽",
                [.mediumDark]: "🙎🏾",
                [.dark]: "🙎🏿"
            ],
            .manPouting:[
                [.light]: "🙎🏻‍♂️",
                [.mediumLight]: "🙎🏼‍♂️",
                [.medium]: "🙎🏽‍♂️",
                [.mediumDark]: "🙎🏾‍♂️",
                [.dark]: "🙎🏿‍♂️"
            ],
            .womanPouting:[
                [.light]: "🙎🏻‍♀️",
                [.mediumLight]: "🙎🏼‍♀️",
                [.medium]: "🙎🏽‍♀️",
                [.mediumDark]: "🙎🏾‍♀️",
                [.dark]: "🙎🏿‍♀️"
            ],
            .personGesturingNo:[
                [.light]: "🙅🏻",
                [.mediumLight]: "🙅🏼",
                [.medium]: "🙅🏽",
                [.mediumDark]: "🙅🏾",
                [.dark]: "🙅🏿"
            ],
            .manGesturingNo:[
                [.light]: "🙅🏻‍♂️",
                [.mediumLight]: "🙅🏼‍♂️",
                [.medium]: "🙅🏽‍♂️",
                [.mediumDark]: "🙅🏾‍♂️",
                [.dark]: "🙅🏿‍♂️"
            ],
            .womanGesturingNo:[
                [.light]: "🙅🏻‍♀️",
                [.mediumLight]: "🙅🏼‍♀️",
                [.medium]: "🙅🏽‍♀️",
                [.mediumDark]: "🙅🏾‍♀️",
                [.dark]: "🙅🏿‍♀️"
            ],
            .personGesturingOk:[
                [.light]: "🙆🏻",
                [.mediumLight]: "🙆🏼",
                [.medium]: "🙆🏽",
                [.mediumDark]: "🙆🏾",
                [.dark]: "🙆🏿"
            ],
            .manGesturingOk:[
                [.light]: "🙆🏻‍♂️",
                [.mediumLight]: "🙆🏼‍♂️",
                [.medium]: "🙆🏽‍♂️",
                [.mediumDark]: "🙆🏾‍♂️",
                [.dark]: "🙆🏿‍♂️"
            ],
            .womanGesturingOk:[
                [.light]: "🙆🏻‍♀️",
                [.mediumLight]: "🙆🏼‍♀️",
                [.medium]: "🙆🏽‍♀️",
                [.mediumDark]: "🙆🏾‍♀️",
                [.dark]: "🙆🏿‍♀️"
            ],
            .personTippingHand:[
                [.light]: "💁🏻",
                [.mediumLight]: "💁🏼",
                [.medium]: "💁🏽",
                [.mediumDark]: "💁🏾",
                [.dark]: "💁🏿"
            ],
            .manTippingHand:[
                [.light]: "💁🏻‍♂️",
                [.mediumLight]: "💁🏼‍♂️",
                [.medium]: "💁🏽‍♂️",
                [.mediumDark]: "💁🏾‍♂️",
                [.dark]: "💁🏿‍♂️"
            ],
            .womanTippingHand:[
                [.light]: "💁🏻‍♀️",
                [.mediumLight]: "💁🏼‍♀️",
                [.medium]: "💁🏽‍♀️",
                [.mediumDark]: "💁🏾‍♀️",
                [.dark]: "💁🏿‍♀️"
            ],
            .personRaisingHand:[
                [.light]: "🙋🏻",
                [.mediumLight]: "🙋🏼",
                [.medium]: "🙋🏽",
                [.mediumDark]: "🙋🏾",
                [.dark]: "🙋🏿"
            ],
            .manRaisingHand:[
                [.light]: "🙋🏻‍♂️",
                [.mediumLight]: "🙋🏼‍♂️",
                [.medium]: "🙋🏽‍♂️",
                [.mediumDark]: "🙋🏾‍♂️",
                [.dark]: "🙋🏿‍♂️"
            ],
            .womanRaisingHand:[
                [.light]: "🙋🏻‍♀️",
                [.mediumLight]: "🙋🏼‍♀️",
                [.medium]: "🙋🏽‍♀️",
                [.mediumDark]: "🙋🏾‍♀️",
                [.dark]: "🙋🏿‍♀️"
            ],
            .deafPerson:[
                [.light]: "🧏🏻",
                [.mediumLight]: "🧏🏼",
                [.medium]: "🧏🏽",
                [.mediumDark]: "🧏🏾",
                [.dark]: "🧏🏿"
            ],
            .deafMan:[
                [.light]: "🧏🏻‍♂️",
                [.mediumLight]: "🧏🏼‍♂️",
                [.medium]: "🧏🏽‍♂️",
                [.mediumDark]: "🧏🏾‍♂️",
                [.dark]: "🧏🏿‍♂️"
            ],
            .deafWoman:[
                [.light]: "🧏🏻‍♀️",
                [.mediumLight]: "🧏🏼‍♀️",
                [.medium]: "🧏🏽‍♀️",
                [.mediumDark]: "🧏🏾‍♀️",
                [.dark]: "🧏🏿‍♀️"
            ],
            .personBowing:[
                [.light]: "🙇🏻",
                [.mediumLight]: "🙇🏼",
                [.medium]: "🙇🏽",
                [.mediumDark]: "🙇🏾",
                [.dark]: "🙇🏿"
            ],
            .manBowing:[
                [.light]: "🙇🏻‍♂️",
                [.mediumLight]: "🙇🏼‍♂️",
                [.medium]: "🙇🏽‍♂️",
                [.mediumDark]: "🙇🏾‍♂️",
                [.dark]: "🙇🏿‍♂️"
            ],
            .womanBowing:[
                [.light]: "🙇🏻‍♀️",
                [.mediumLight]: "🙇🏼‍♀️",
                [.medium]: "🙇🏽‍♀️",
                [.mediumDark]: "🙇🏾‍♀️",
                [.dark]: "🙇🏿‍♀️"
            ],
            .personFacepalming:[
                [.light]: "🤦🏻",
                [.mediumLight]: "🤦🏼",
                [.medium]: "🤦🏽",
                [.mediumDark]: "🤦🏾",
                [.dark]: "🤦🏿"
            ],
            .manFacepalming:[
                [.light]: "🤦🏻‍♂️",
                [.mediumLight]: "🤦🏼‍♂️",
                [.medium]: "🤦🏽‍♂️",
                [.mediumDark]: "🤦🏾‍♂️",
                [.dark]: "🤦🏿‍♂️"
            ],
            .womanFacepalming:[
                [.light]: "🤦🏻‍♀️",
                [.mediumLight]: "🤦🏼‍♀️",
                [.medium]: "🤦🏽‍♀️",
                [.mediumDark]: "🤦🏾‍♀️",
                [.dark]: "🤦🏿‍♀️"
            ],
            .personShrugging:[
                [.light]: "🤷🏻",
                [.mediumLight]: "🤷🏼",
                [.medium]: "🤷🏽",
                [.mediumDark]: "🤷🏾",
                [.dark]: "🤷🏿"
            ],
            .manShrugging:[
                [.light]: "🤷🏻‍♂️",
                [.mediumLight]: "🤷🏼‍♂️",
                [.medium]: "🤷🏽‍♂️",
                [.mediumDark]: "🤷🏾‍♂️",
                [.dark]: "🤷🏿‍♂️"
            ],
            .womanShrugging:[
                [.light]: "🤷🏻‍♀️",
                [.mediumLight]: "🤷🏼‍♀️",
                [.medium]: "🤷🏽‍♀️",
                [.mediumDark]: "🤷🏾‍♀️",
                [.dark]: "🤷🏿‍♀️"
            ],
            .healthWorker:[
                [.light]: "🧑🏻‍⚕️",
                [.mediumLight]: "🧑🏼‍⚕️",
                [.medium]: "🧑🏽‍⚕️",
                [.mediumDark]: "🧑🏾‍⚕️",
                [.dark]: "🧑🏿‍⚕️"
            ],
            .manHealthWorker:[
                [.light]: "👨🏻‍⚕️",
                [.mediumLight]: "👨🏼‍⚕️",
                [.medium]: "👨🏽‍⚕️",
                [.mediumDark]: "👨🏾‍⚕️",
                [.dark]: "👨🏿‍⚕️"
            ],
            .womanHealthWorker:[
                [.light]: "👩🏻‍⚕️",
                [.mediumLight]: "👩🏼‍⚕️",
                [.medium]: "👩🏽‍⚕️",
                [.mediumDark]: "👩🏾‍⚕️",
                [.dark]: "👩🏿‍⚕️"
            ],
            .student:[
                [.light]: "🧑🏻‍🎓",
                [.mediumLight]: "🧑🏼‍🎓",
                [.medium]: "🧑🏽‍🎓",
                [.mediumDark]: "🧑🏾‍🎓",
                [.dark]: "🧑🏿‍🎓"
            ],
            .manStudent:[
                [.light]: "👨🏻‍🎓",
                [.mediumLight]: "👨🏼‍🎓",
                [.medium]: "👨🏽‍🎓",
                [.mediumDark]: "👨🏾‍🎓",
                [.dark]: "👨🏿‍🎓"
            ],
            .womanStudent:[
                [.light]: "👩🏻‍🎓",
                [.mediumLight]: "👩🏼‍🎓",
                [.medium]: "👩🏽‍🎓",
                [.mediumDark]: "👩🏾‍🎓",
                [.dark]: "👩🏿‍🎓"
            ],
            .teacher:[
                [.light]: "🧑🏻‍🏫",
                [.mediumLight]: "🧑🏼‍🏫",
                [.medium]: "🧑🏽‍🏫",
                [.mediumDark]: "🧑🏾‍🏫",
                [.dark]: "🧑🏿‍🏫"
            ],
            .manTeacher:[
                [.light]: "👨🏻‍🏫",
                [.mediumLight]: "👨🏼‍🏫",
                [.medium]: "👨🏽‍🏫",
                [.mediumDark]: "👨🏾‍🏫",
                [.dark]: "👨🏿‍🏫"
            ],
            .womanTeacher:[
                [.light]: "👩🏻‍🏫",
                [.mediumLight]: "👩🏼‍🏫",
                [.medium]: "👩🏽‍🏫",
                [.mediumDark]: "👩🏾‍🏫",
                [.dark]: "👩🏿‍🏫"
            ],
            .judge:[
                [.light]: "🧑🏻‍⚖️",
                [.mediumLight]: "🧑🏼‍⚖️",
                [.medium]: "🧑🏽‍⚖️",
                [.mediumDark]: "🧑🏾‍⚖️",
                [.dark]: "🧑🏿‍⚖️"
            ],
            .manJudge:[
                [.light]: "👨🏻‍⚖️",
                [.mediumLight]: "👨🏼‍⚖️",
                [.medium]: "👨🏽‍⚖️",
                [.mediumDark]: "👨🏾‍⚖️",
                [.dark]: "👨🏿‍⚖️"
            ],
            .womanJudge:[
                [.light]: "👩🏻‍⚖️",
                [.mediumLight]: "👩🏼‍⚖️",
                [.medium]: "👩🏽‍⚖️",
                [.mediumDark]: "👩🏾‍⚖️",
                [.dark]: "👩🏿‍⚖️"
            ],
            .farmer:[
                [.light]: "🧑🏻‍🌾",
                [.mediumLight]: "🧑🏼‍🌾",
                [.medium]: "🧑🏽‍🌾",
                [.mediumDark]: "🧑🏾‍🌾",
                [.dark]: "🧑🏿‍🌾"
            ],
            .manFarmer:[
                [.light]: "👨🏻‍🌾",
                [.mediumLight]: "👨🏼‍🌾",
                [.medium]: "👨🏽‍🌾",
                [.mediumDark]: "👨🏾‍🌾",
                [.dark]: "👨🏿‍🌾"
            ],
            .womanFarmer:[
                [.light]: "👩🏻‍🌾",
                [.mediumLight]: "👩🏼‍🌾",
                [.medium]: "👩🏽‍🌾",
                [.mediumDark]: "👩🏾‍🌾",
                [.dark]: "👩🏿‍🌾"
            ],
            .cook:[
                [.light]: "🧑🏻‍🍳",
                [.mediumLight]: "🧑🏼‍🍳",
                [.medium]: "🧑🏽‍🍳",
                [.mediumDark]: "🧑🏾‍🍳",
                [.dark]: "🧑🏿‍🍳"
            ],
            .manCook:[
                [.light]: "👨🏻‍🍳",
                [.mediumLight]: "👨🏼‍🍳",
                [.medium]: "👨🏽‍🍳",
                [.mediumDark]: "👨🏾‍🍳",
                [.dark]: "👨🏿‍🍳"
            ],
            .womanCook:[
                [.light]: "👩🏻‍🍳",
                [.mediumLight]: "👩🏼‍🍳",
                [.medium]: "👩🏽‍🍳",
                [.mediumDark]: "👩🏾‍🍳",
                [.dark]: "👩🏿‍🍳"
            ],
            .mechanic:[
                [.light]: "🧑🏻‍🔧",
                [.mediumLight]: "🧑🏼‍🔧",
                [.medium]: "🧑🏽‍🔧",
                [.mediumDark]: "🧑🏾‍🔧",
                [.dark]: "🧑🏿‍🔧"
            ],
            .manMechanic:[
                [.light]: "👨🏻‍🔧",
                [.mediumLight]: "👨🏼‍🔧",
                [.medium]: "👨🏽‍🔧",
                [.mediumDark]: "👨🏾‍🔧",
                [.dark]: "👨🏿‍🔧"
            ],
            .womanMechanic:[
                [.light]: "👩🏻‍🔧",
                [.mediumLight]: "👩🏼‍🔧",
                [.medium]: "👩🏽‍🔧",
                [.mediumDark]: "👩🏾‍🔧",
                [.dark]: "👩🏿‍🔧"
            ],
            .factoryWorker:[
                [.light]: "🧑🏻‍🏭",
                [.mediumLight]: "🧑🏼‍🏭",
                [.medium]: "🧑🏽‍🏭",
                [.mediumDark]: "🧑🏾‍🏭",
                [.dark]: "🧑🏿‍🏭"
            ],
            .manFactoryWorker:[
                [.light]: "👨🏻‍🏭",
                [.mediumLight]: "👨🏼‍🏭",
                [.medium]: "👨🏽‍🏭",
                [.mediumDark]: "👨🏾‍🏭",
                [.dark]: "👨🏿‍🏭"
            ],
            .womanFactoryWorker:[
                [.light]: "👩🏻‍🏭",
                [.mediumLight]: "👩🏼‍🏭",
                [.medium]: "👩🏽‍🏭",
                [.mediumDark]: "👩🏾‍🏭",
                [.dark]: "👩🏿‍🏭"
            ],
            .officeWorker:[
                [.light]: "🧑🏻‍💼",
                [.mediumLight]: "🧑🏼‍💼",
                [.medium]: "🧑🏽‍💼",
                [.mediumDark]: "🧑🏾‍💼",
                [.dark]: "🧑🏿‍💼"
            ],
            .manOfficeWorker:[
                [.light]: "👨🏻‍💼",
                [.mediumLight]: "👨🏼‍💼",
                [.medium]: "👨🏽‍💼",
                [.mediumDark]: "👨🏾‍💼",
                [.dark]: "👨🏿‍💼"
            ],
            .womanOfficeWorker:[
                [.light]: "👩🏻‍💼",
                [.mediumLight]: "👩🏼‍💼",
                [.medium]: "👩🏽‍💼",
                [.mediumDark]: "👩🏾‍💼",
                [.dark]: "👩🏿‍💼"
            ],
            .scientist:[
                [.light]: "🧑🏻‍🔬",
                [.mediumLight]: "🧑🏼‍🔬",
                [.medium]: "🧑🏽‍🔬",
                [.mediumDark]: "🧑🏾‍🔬",
                [.dark]: "🧑🏿‍🔬"
            ],
            .manScientist:[
                [.light]: "👨🏻‍🔬",
                [.mediumLight]: "👨🏼‍🔬",
                [.medium]: "👨🏽‍🔬",
                [.mediumDark]: "👨🏾‍🔬",
                [.dark]: "👨🏿‍🔬"
            ],
            .womanScientist:[
                [.light]: "👩🏻‍🔬",
                [.mediumLight]: "👩🏼‍🔬",
                [.medium]: "👩🏽‍🔬",
                [.mediumDark]: "👩🏾‍🔬",
                [.dark]: "👩🏿‍🔬"
            ],
            .technologist:[
                [.light]: "🧑🏻‍💻",
                [.mediumLight]: "🧑🏼‍💻",
                [.medium]: "🧑🏽‍💻",
                [.mediumDark]: "🧑🏾‍💻",
                [.dark]: "🧑🏿‍💻"
            ],
            .manTechnologist:[
                [.light]: "👨🏻‍💻",
                [.mediumLight]: "👨🏼‍💻",
                [.medium]: "👨🏽‍💻",
                [.mediumDark]: "👨🏾‍💻",
                [.dark]: "👨🏿‍💻"
            ],
            .womanTechnologist:[
                [.light]: "👩🏻‍💻",
                [.mediumLight]: "👩🏼‍💻",
                [.medium]: "👩🏽‍💻",
                [.mediumDark]: "👩🏾‍💻",
                [.dark]: "👩🏿‍💻"
            ],
            .singer:[
                [.light]: "🧑🏻‍🎤",
                [.mediumLight]: "🧑🏼‍🎤",
                [.medium]: "🧑🏽‍🎤",
                [.mediumDark]: "🧑🏾‍🎤",
                [.dark]: "🧑🏿‍🎤"
            ],
            .manSinger:[
                [.light]: "👨🏻‍🎤",
                [.mediumLight]: "👨🏼‍🎤",
                [.medium]: "👨🏽‍🎤",
                [.mediumDark]: "👨🏾‍🎤",
                [.dark]: "👨🏿‍🎤"
            ],
            .womanSinger:[
                [.light]: "👩🏻‍🎤",
                [.mediumLight]: "👩🏼‍🎤",
                [.medium]: "👩🏽‍🎤",
                [.mediumDark]: "👩🏾‍🎤",
                [.dark]: "👩🏿‍🎤"
            ],
            .artist:[
                [.light]: "🧑🏻‍🎨",
                [.mediumLight]: "🧑🏼‍🎨",
                [.medium]: "🧑🏽‍🎨",
                [.mediumDark]: "🧑🏾‍🎨",
                [.dark]: "🧑🏿‍🎨"
            ],
            .manArtist:[
                [.light]: "👨🏻‍🎨",
                [.mediumLight]: "👨🏼‍🎨",
                [.medium]: "👨🏽‍🎨",
                [.mediumDark]: "👨🏾‍🎨",
                [.dark]: "👨🏿‍🎨"
            ],
            .womanArtist:[
                [.light]: "👩🏻‍🎨",
                [.mediumLight]: "👩🏼‍🎨",
                [.medium]: "👩🏽‍🎨",
                [.mediumDark]: "👩🏾‍🎨",
                [.dark]: "👩🏿‍🎨"
            ],
            .pilot:[
                [.light]: "🧑🏻‍✈️",
                [.mediumLight]: "🧑🏼‍✈️",
                [.medium]: "🧑🏽‍✈️",
                [.mediumDark]: "🧑🏾‍✈️",
                [.dark]: "🧑🏿‍✈️"
            ],
            .manPilot:[
                [.light]: "👨🏻‍✈️",
                [.mediumLight]: "👨🏼‍✈️",
                [.medium]: "👨🏽‍✈️",
                [.mediumDark]: "👨🏾‍✈️",
                [.dark]: "👨🏿‍✈️"
            ],
            .womanPilot:[
                [.light]: "👩🏻‍✈️",
                [.mediumLight]: "👩🏼‍✈️",
                [.medium]: "👩🏽‍✈️",
                [.mediumDark]: "👩🏾‍✈️",
                [.dark]: "👩🏿‍✈️"
            ],
            .astronaut:[
                [.light]: "🧑🏻‍🚀",
                [.mediumLight]: "🧑🏼‍🚀",
                [.medium]: "🧑🏽‍🚀",
                [.mediumDark]: "🧑🏾‍🚀",
                [.dark]: "🧑🏿‍🚀"
            ],
            .manAstronaut:[
                [.light]: "👨🏻‍🚀",
                [.mediumLight]: "👨🏼‍🚀",
                [.medium]: "👨🏽‍🚀",
                [.mediumDark]: "👨🏾‍🚀",
                [.dark]: "👨🏿‍🚀"
            ],
            .womanAstronaut:[
                [.light]: "👩🏻‍🚀",
                [.mediumLight]: "👩🏼‍🚀",
                [.medium]: "👩🏽‍🚀",
                [.mediumDark]: "👩🏾‍🚀",
                [.dark]: "👩🏿‍🚀"
            ],
            .firefighter:[
                [.light]: "🧑🏻‍🚒",
                [.mediumLight]: "🧑🏼‍🚒",
                [.medium]: "🧑🏽‍🚒",
                [.mediumDark]: "🧑🏾‍🚒",
                [.dark]: "🧑🏿‍🚒"
            ],
            .manFirefighter:[
                [.light]: "👨🏻‍🚒",
                [.mediumLight]: "👨🏼‍🚒",
                [.medium]: "👨🏽‍🚒",
                [.mediumDark]: "👨🏾‍🚒",
                [.dark]: "👨🏿‍🚒"
            ],
            .womanFirefighter:[
                [.light]: "👩🏻‍🚒",
                [.mediumLight]: "👩🏼‍🚒",
                [.medium]: "👩🏽‍🚒",
                [.mediumDark]: "👩🏾‍🚒",
                [.dark]: "👩🏿‍🚒"
            ],
            .policeOfficer:[
                [.light]: "👮🏻",
                [.mediumLight]: "👮🏼",
                [.medium]: "👮🏽",
                [.mediumDark]: "👮🏾",
                [.dark]: "👮🏿"
            ],
            .manPoliceOfficer:[
                [.light]: "👮🏻‍♂️",
                [.mediumLight]: "👮🏼‍♂️",
                [.medium]: "👮🏽‍♂️",
                [.mediumDark]: "👮🏾‍♂️",
                [.dark]: "👮🏿‍♂️"
            ],
            .womanPoliceOfficer:[
                [.light]: "👮🏻‍♀️",
                [.mediumLight]: "👮🏼‍♀️",
                [.medium]: "👮🏽‍♀️",
                [.mediumDark]: "👮🏾‍♀️",
                [.dark]: "👮🏿‍♀️"
            ],
            .detective:[
                [.light]: "🕵🏻",
                [.mediumLight]: "🕵🏼",
                [.medium]: "🕵🏽",
                [.mediumDark]: "🕵🏾",
                [.dark]: "🕵🏿"
            ],
            .manDetective:[
                [.light]: "🕵🏻‍♂️",
                [.mediumLight]: "🕵🏼‍♂️",
                [.medium]: "🕵🏽‍♂️",
                [.mediumDark]: "🕵🏾‍♂️",
                [.dark]: "🕵🏿‍♂️"
            ],
            .womanDetective:[
                [.light]: "🕵🏻‍♀️",
                [.mediumLight]: "🕵🏼‍♀️",
                [.medium]: "🕵🏽‍♀️",
                [.mediumDark]: "🕵🏾‍♀️",
                [.dark]: "🕵🏿‍♀️"
            ],
            .personGuard:[
                [.light]: "💂🏻",
                [.mediumLight]: "💂🏼",
                [.medium]: "💂🏽",
                [.mediumDark]: "💂🏾",
                [.dark]: "💂🏿"
            ],
            .manGuard:[
                [.light]: "💂🏻‍♂️",
                [.mediumLight]: "💂🏼‍♂️",
                [.medium]: "💂🏽‍♂️",
                [.mediumDark]: "💂🏾‍♂️",
                [.dark]: "💂🏿‍♂️"
            ],
            .womanGuard:[
                [.light]: "💂🏻‍♀️",
                [.mediumLight]: "💂🏼‍♀️",
                [.medium]: "💂🏽‍♀️",
                [.mediumDark]: "💂🏾‍♀️",
                [.dark]: "💂🏿‍♀️"
            ],
            .ninja:[
                [.light]: "🥷🏻",
                [.mediumLight]: "🥷🏼",
                [.medium]: "🥷🏽",
                [.mediumDark]: "🥷🏾",
                [.dark]: "🥷🏿"
            ],
            .constructionWorker:[
                [.light]: "👷🏻",
                [.mediumLight]: "👷🏼",
                [.medium]: "👷🏽",
                [.mediumDark]: "👷🏾",
                [.dark]: "👷🏿"
            ],
            .manConstructionWorker:[
                [.light]: "👷🏻‍♂️",
                [.mediumLight]: "👷🏼‍♂️",
                [.medium]: "👷🏽‍♂️",
                [.mediumDark]: "👷🏾‍♂️",
                [.dark]: "👷🏿‍♂️"
            ],
            .womanConstructionWorker:[
                [.light]: "👷🏻‍♀️",
                [.mediumLight]: "👷🏼‍♀️",
                [.medium]: "👷🏽‍♀️",
                [.mediumDark]: "👷🏾‍♀️",
                [.dark]: "👷🏿‍♀️"
            ],
            .personWithCrown:[
                [.light]: "🫅🏻",
                [.mediumLight]: "🫅🏼",
                [.medium]: "🫅🏽",
                [.mediumDark]: "🫅🏾",
                [.dark]: "🫅🏿"
            ],
            .prince:[
                [.light]: "🤴🏻",
                [.mediumLight]: "🤴🏼",
                [.medium]: "🤴🏽",
                [.mediumDark]: "🤴🏾",
                [.dark]: "🤴🏿"
            ],
            .princess:[
                [.light]: "👸🏻",
                [.mediumLight]: "👸🏼",
                [.medium]: "👸🏽",
                [.mediumDark]: "👸🏾",
                [.dark]: "👸🏿"
            ],
            .personWearingTurban:[
                [.light]: "👳🏻",
                [.mediumLight]: "👳🏼",
                [.medium]: "👳🏽",
                [.mediumDark]: "👳🏾",
                [.dark]: "👳🏿"
            ],
            .manWearingTurban:[
                [.light]: "👳🏻‍♂️",
                [.mediumLight]: "👳🏼‍♂️",
                [.medium]: "👳🏽‍♂️",
                [.mediumDark]: "👳🏾‍♂️",
                [.dark]: "👳🏿‍♂️"
            ],
            .womanWearingTurban:[
                [.light]: "👳🏻‍♀️",
                [.mediumLight]: "👳🏼‍♀️",
                [.medium]: "👳🏽‍♀️",
                [.mediumDark]: "👳🏾‍♀️",
                [.dark]: "👳🏿‍♀️"
            ],
            .personWithSkullcap:[
                [.light]: "👲🏻",
                [.mediumLight]: "👲🏼",
                [.medium]: "👲🏽",
                [.mediumDark]: "👲🏾",
                [.dark]: "👲🏿"
            ],
            .womanWithHeadscarf:[
                [.light]: "🧕🏻",
                [.mediumLight]: "🧕🏼",
                [.medium]: "🧕🏽",
                [.mediumDark]: "🧕🏾",
                [.dark]: "🧕🏿"
            ],
            .personInTuxedo:[
                [.light]: "🤵🏻",
                [.mediumLight]: "🤵🏼",
                [.medium]: "🤵🏽",
                [.mediumDark]: "🤵🏾",
                [.dark]: "🤵🏿"
            ],
            .manInTuxedo:[
                [.light]: "🤵🏻‍♂️",
                [.mediumLight]: "🤵🏼‍♂️",
                [.medium]: "🤵🏽‍♂️",
                [.mediumDark]: "🤵🏾‍♂️",
                [.dark]: "🤵🏿‍♂️"
            ],
            .womanInTuxedo:[
                [.light]: "🤵🏻‍♀️",
                [.mediumLight]: "🤵🏼‍♀️",
                [.medium]: "🤵🏽‍♀️",
                [.mediumDark]: "🤵🏾‍♀️",
                [.dark]: "🤵🏿‍♀️"
            ],
            .personWithVeil:[
                [.light]: "👰🏻",
                [.mediumLight]: "👰🏼",
                [.medium]: "👰🏽",
                [.mediumDark]: "👰🏾",
                [.dark]: "👰🏿"
            ],
            .manWithVeil:[
                [.light]: "👰🏻‍♂️",
                [.mediumLight]: "👰🏼‍♂️",
                [.medium]: "👰🏽‍♂️",
                [.mediumDark]: "👰🏾‍♂️",
                [.dark]: "👰🏿‍♂️"
            ],
            .womanWithVeil:[
                [.light]: "👰🏻‍♀️",
                [.mediumLight]: "👰🏼‍♀️",
                [.medium]: "👰🏽‍♀️",
                [.mediumDark]: "👰🏾‍♀️",
                [.dark]: "👰🏿‍♀️"
            ],
            .pregnantWoman:[
                [.light]: "🤰🏻",
                [.mediumLight]: "🤰🏼",
                [.medium]: "🤰🏽",
                [.mediumDark]: "🤰🏾",
                [.dark]: "🤰🏿"
            ],
            .pregnantMan:[
                [.light]: "🫃🏻",
                [.mediumLight]: "🫃🏼",
                [.medium]: "🫃🏽",
                [.mediumDark]: "🫃🏾",
                [.dark]: "🫃🏿"
            ],
            .pregnantPerson:[
                [.light]: "🫄🏻",
                [.mediumLight]: "🫄🏼",
                [.medium]: "🫄🏽",
                [.mediumDark]: "🫄🏾",
                [.dark]: "🫄🏿"
            ],
            .breastFeeding:[
                [.light]: "🤱🏻",
                [.mediumLight]: "🤱🏼",
                [.medium]: "🤱🏽",
                [.mediumDark]: "🤱🏾",
                [.dark]: "🤱🏿"
            ],
            .womanFeedingBaby:[
                [.light]: "👩🏻‍🍼",
                [.mediumLight]: "👩🏼‍🍼",
                [.medium]: "👩🏽‍🍼",
                [.mediumDark]: "👩🏾‍🍼",
                [.dark]: "👩🏿‍🍼"
            ],
            .manFeedingBaby:[
                [.light]: "👨🏻‍🍼",
                [.mediumLight]: "👨🏼‍🍼",
                [.medium]: "👨🏽‍🍼",
                [.mediumDark]: "👨🏾‍🍼",
                [.dark]: "👨🏿‍🍼"
            ],
            .personFeedingBaby:[
                [.light]: "🧑🏻‍🍼",
                [.mediumLight]: "🧑🏼‍🍼",
                [.medium]: "🧑🏽‍🍼",
                [.mediumDark]: "🧑🏾‍🍼",
                [.dark]: "🧑🏿‍🍼"
            ],
            .babyAngel:[
                [.light]: "👼🏻",
                [.mediumLight]: "👼🏼",
                [.medium]: "👼🏽",
                [.mediumDark]: "👼🏾",
                [.dark]: "👼🏿"
            ],
            .santaClaus:[
                [.light]: "🎅🏻",
                [.mediumLight]: "🎅🏼",
                [.medium]: "🎅🏽",
                [.mediumDark]: "🎅🏾",
                [.dark]: "🎅🏿"
            ],
            .mrsClaus:[
                [.light]: "🤶🏻",
                [.mediumLight]: "🤶🏼",
                [.medium]: "🤶🏽",
                [.mediumDark]: "🤶🏾",
                [.dark]: "🤶🏿"
            ],
            .mxClaus:[
                [.light]: "🧑🏻‍🎄",
                [.mediumLight]: "🧑🏼‍🎄",
                [.medium]: "🧑🏽‍🎄",
                [.mediumDark]: "🧑🏾‍🎄",
                [.dark]: "🧑🏿‍🎄"
            ],
            .superhero:[
                [.light]: "🦸🏻",
                [.mediumLight]: "🦸🏼",
                [.medium]: "🦸🏽",
                [.mediumDark]: "🦸🏾",
                [.dark]: "🦸🏿"
            ],
            .manSuperhero:[
                [.light]: "🦸🏻‍♂️",
                [.mediumLight]: "🦸🏼‍♂️",
                [.medium]: "🦸🏽‍♂️",
                [.mediumDark]: "🦸🏾‍♂️",
                [.dark]: "🦸🏿‍♂️"
            ],
            .womanSuperhero:[
                [.light]: "🦸🏻‍♀️",
                [.mediumLight]: "🦸🏼‍♀️",
                [.medium]: "🦸🏽‍♀️",
                [.mediumDark]: "🦸🏾‍♀️",
                [.dark]: "🦸🏿‍♀️"
            ],
            .supervillain:[
                [.light]: "🦹🏻",
                [.mediumLight]: "🦹🏼",
                [.medium]: "🦹🏽",
                [.mediumDark]: "🦹🏾",
                [.dark]: "🦹🏿"
            ],
            .manSupervillain:[
                [.light]: "🦹🏻‍♂️",
                [.mediumLight]: "🦹🏼‍♂️",
                [.medium]: "🦹🏽‍♂️",
                [.mediumDark]: "🦹🏾‍♂️",
                [.dark]: "🦹🏿‍♂️"
            ],
            .womanSupervillain:[
                [.light]: "🦹🏻‍♀️",
                [.mediumLight]: "🦹🏼‍♀️",
                [.medium]: "🦹🏽‍♀️",
                [.mediumDark]: "🦹🏾‍♀️",
                [.dark]: "🦹🏿‍♀️"
            ],
            .mage:[
                [.light]: "🧙🏻",
                [.mediumLight]: "🧙🏼",
                [.medium]: "🧙🏽",
                [.mediumDark]: "🧙🏾",
                [.dark]: "🧙🏿"
            ],
            .manMage:[
                [.light]: "🧙🏻‍♂️",
                [.mediumLight]: "🧙🏼‍♂️",
                [.medium]: "🧙🏽‍♂️",
                [.mediumDark]: "🧙🏾‍♂️",
                [.dark]: "🧙🏿‍♂️"
            ],
            .womanMage:[
                [.light]: "🧙🏻‍♀️",
                [.mediumLight]: "🧙🏼‍♀️",
                [.medium]: "🧙🏽‍♀️",
                [.mediumDark]: "🧙🏾‍♀️",
                [.dark]: "🧙🏿‍♀️"
            ],
            .fairy:[
                [.light]: "🧚🏻",
                [.mediumLight]: "🧚🏼",
                [.medium]: "🧚🏽",
                [.mediumDark]: "🧚🏾",
                [.dark]: "🧚🏿"
            ],
            .manFairy:[
                [.light]: "🧚🏻‍♂️",
                [.mediumLight]: "🧚🏼‍♂️",
                [.medium]: "🧚🏽‍♂️",
                [.mediumDark]: "🧚🏾‍♂️",
                [.dark]: "🧚🏿‍♂️"
            ],
            .womanFairy:[
                [.light]: "🧚🏻‍♀️",
                [.mediumLight]: "🧚🏼‍♀️",
                [.medium]: "🧚🏽‍♀️",
                [.mediumDark]: "🧚🏾‍♀️",
                [.dark]: "🧚🏿‍♀️"
            ],
            .vampire:[
                [.light]: "🧛🏻",
                [.mediumLight]: "🧛🏼",
                [.medium]: "🧛🏽",
                [.mediumDark]: "🧛🏾",
                [.dark]: "🧛🏿"
            ],
            .manVampire:[
                [.light]: "🧛🏻‍♂️",
                [.mediumLight]: "🧛🏼‍♂️",
                [.medium]: "🧛🏽‍♂️",
                [.mediumDark]: "🧛🏾‍♂️",
                [.dark]: "🧛🏿‍♂️"
            ],
            .womanVampire:[
                [.light]: "🧛🏻‍♀️",
                [.mediumLight]: "🧛🏼‍♀️",
                [.medium]: "🧛🏽‍♀️",
                [.mediumDark]: "🧛🏾‍♀️",
                [.dark]: "🧛🏿‍♀️"
            ],
            .merperson:[
                [.light]: "🧜🏻",
                [.mediumLight]: "🧜🏼",
                [.medium]: "🧜🏽",
                [.mediumDark]: "🧜🏾",
                [.dark]: "🧜🏿"
            ],
            .merman:[
                [.light]: "🧜🏻‍♂️",
                [.mediumLight]: "🧜🏼‍♂️",
                [.medium]: "🧜🏽‍♂️",
                [.mediumDark]: "🧜🏾‍♂️",
                [.dark]: "🧜🏿‍♂️"
            ],
            .mermaid:[
                [.light]: "🧜🏻‍♀️",
                [.mediumLight]: "🧜🏼‍♀️",
                [.medium]: "🧜🏽‍♀️",
                [.mediumDark]: "🧜🏾‍♀️",
                [.dark]: "🧜🏿‍♀️"
            ],
            .elf:[
                [.light]: "🧝🏻",
                [.mediumLight]: "🧝🏼",
                [.medium]: "🧝🏽",
                [.mediumDark]: "🧝🏾",
                [.dark]: "🧝🏿"
            ],
            .manElf:[
                [.light]: "🧝🏻‍♂️",
                [.mediumLight]: "🧝🏼‍♂️",
                [.medium]: "🧝🏽‍♂️",
                [.mediumDark]: "🧝🏾‍♂️",
                [.dark]: "🧝🏿‍♂️"
            ],
            .womanElf:[
                [.light]: "🧝🏻‍♀️",
                [.mediumLight]: "🧝🏼‍♀️",
                [.medium]: "🧝🏽‍♀️",
                [.mediumDark]: "🧝🏾‍♀️",
                [.dark]: "🧝🏿‍♀️"
            ],
            .personGettingMassage:[
                [.light]: "💆🏻",
                [.mediumLight]: "💆🏼",
                [.medium]: "💆🏽",
                [.mediumDark]: "💆🏾",
                [.dark]: "💆🏿"
            ],
            .manGettingMassage:[
                [.light]: "💆🏻‍♂️",
                [.mediumLight]: "💆🏼‍♂️",
                [.medium]: "💆🏽‍♂️",
                [.mediumDark]: "💆🏾‍♂️",
                [.dark]: "💆🏿‍♂️"
            ],
            .womanGettingMassage:[
                [.light]: "💆🏻‍♀️",
                [.mediumLight]: "💆🏼‍♀️",
                [.medium]: "💆🏽‍♀️",
                [.mediumDark]: "💆🏾‍♀️",
                [.dark]: "💆🏿‍♀️"
            ],
            .personGettingHaircut:[
                [.light]: "💇🏻",
                [.mediumLight]: "💇🏼",
                [.medium]: "💇🏽",
                [.mediumDark]: "💇🏾",
                [.dark]: "💇🏿"
            ],
            .manGettingHaircut:[
                [.light]: "💇🏻‍♂️",
                [.mediumLight]: "💇🏼‍♂️",
                [.medium]: "💇🏽‍♂️",
                [.mediumDark]: "💇🏾‍♂️",
                [.dark]: "💇🏿‍♂️"
            ],
            .womanGettingHaircut:[
                [.light]: "💇🏻‍♀️",
                [.mediumLight]: "💇🏼‍♀️",
                [.medium]: "💇🏽‍♀️",
                [.mediumDark]: "💇🏾‍♀️",
                [.dark]: "💇🏿‍♀️"
            ],
            .personWalking:[
                [.light]: "🚶🏻",
                [.mediumLight]: "🚶🏼",
                [.medium]: "🚶🏽",
                [.mediumDark]: "🚶🏾",
                [.dark]: "🚶🏿"
            ],
            .manWalking:[
                [.light]: "🚶🏻‍♂️",
                [.mediumLight]: "🚶🏼‍♂️",
                [.medium]: "🚶🏽‍♂️",
                [.mediumDark]: "🚶🏾‍♂️",
                [.dark]: "🚶🏿‍♂️"
            ],
            .womanWalking:[
                [.light]: "🚶🏻‍♀️",
                [.mediumLight]: "🚶🏼‍♀️",
                [.medium]: "🚶🏽‍♀️",
                [.mediumDark]: "🚶🏾‍♀️",
                [.dark]: "🚶🏿‍♀️"
            ],
            .personWalkingFacingRight:[
                [.light]: "🚶🏻‍➡️",
                [.mediumLight]: "🚶🏼‍➡️",
                [.medium]: "🚶🏽‍➡️",
                [.mediumDark]: "🚶🏾‍➡️",
                [.dark]: "🚶🏿‍➡️"
            ],
            .womanWalkingFacingRight:[
                [.light]: "🚶🏻‍♀️‍➡️",
                [.mediumLight]: "🚶🏼‍♀️‍➡️",
                [.medium]: "🚶🏽‍♀️‍➡️",
                [.mediumDark]: "🚶🏾‍♀️‍➡️",
                [.dark]: "🚶🏿‍♀️‍➡️"
            ],
            .manWalkingFacingRight:[
                [.light]: "🚶🏻‍♂️‍➡️",
                [.mediumLight]: "🚶🏼‍♂️‍➡️",
                [.medium]: "🚶🏽‍♂️‍➡️",
                [.mediumDark]: "🚶🏾‍♂️‍➡️",
                [.dark]: "🚶🏿‍♂️‍➡️"
            ],
            .personStanding:[
                [.light]: "🧍🏻",
                [.mediumLight]: "🧍🏼",
                [.medium]: "🧍🏽",
                [.mediumDark]: "🧍🏾",
                [.dark]: "🧍🏿"
            ],
            .manStanding:[
                [.light]: "🧍🏻‍♂️",
                [.mediumLight]: "🧍🏼‍♂️",
                [.medium]: "🧍🏽‍♂️",
                [.mediumDark]: "🧍🏾‍♂️",
                [.dark]: "🧍🏿‍♂️"
            ],
            .womanStanding:[
                [.light]: "🧍🏻‍♀️",
                [.mediumLight]: "🧍🏼‍♀️",
                [.medium]: "🧍🏽‍♀️",
                [.mediumDark]: "🧍🏾‍♀️",
                [.dark]: "🧍🏿‍♀️"
            ],
            .personKneeling:[
                [.light]: "🧎🏻",
                [.mediumLight]: "🧎🏼",
                [.medium]: "🧎🏽",
                [.mediumDark]: "🧎🏾",
                [.dark]: "🧎🏿"
            ],
            .manKneeling:[
                [.light]: "🧎🏻‍♂️",
                [.mediumLight]: "🧎🏼‍♂️",
                [.medium]: "🧎🏽‍♂️",
                [.mediumDark]: "🧎🏾‍♂️",
                [.dark]: "🧎🏿‍♂️"
            ],
            .womanKneeling:[
                [.light]: "🧎🏻‍♀️",
                [.mediumLight]: "🧎🏼‍♀️",
                [.medium]: "🧎🏽‍♀️",
                [.mediumDark]: "🧎🏾‍♀️",
                [.dark]: "🧎🏿‍♀️"
            ],
            .personKneelingFacingRight:[
                [.light]: "🧎🏻‍➡️",
                [.mediumLight]: "🧎🏼‍➡️",
                [.medium]: "🧎🏽‍➡️",
                [.mediumDark]: "🧎🏾‍➡️",
                [.dark]: "🧎🏿‍➡️"
            ],
            .womanKneelingFacingRight:[
                [.light]: "🧎🏻‍♀️‍➡️",
                [.mediumLight]: "🧎🏼‍♀️‍➡️",
                [.medium]: "🧎🏽‍♀️‍➡️",
                [.mediumDark]: "🧎🏾‍♀️‍➡️",
                [.dark]: "🧎🏿‍♀️‍➡️"
            ],
            .manKneelingFacingRight:[
                [.light]: "🧎🏻‍♂️‍➡️",
                [.mediumLight]: "🧎🏼‍♂️‍➡️",
                [.medium]: "🧎🏽‍♂️‍➡️",
                [.mediumDark]: "🧎🏾‍♂️‍➡️",
                [.dark]: "🧎🏿‍♂️‍➡️"
            ],
            .personWithWhiteCane:[
                [.light]: "🧑🏻‍🦯",
                [.mediumLight]: "🧑🏼‍🦯",
                [.medium]: "🧑🏽‍🦯",
                [.mediumDark]: "🧑🏾‍🦯",
                [.dark]: "🧑🏿‍🦯"
            ],
            .personWithWhiteCaneFacingRight:[
                [.light]: "🧑🏻‍🦯‍➡️",
                [.mediumLight]: "🧑🏼‍🦯‍➡️",
                [.medium]: "🧑🏽‍🦯‍➡️",
                [.mediumDark]: "🧑🏾‍🦯‍➡️",
                [.dark]: "🧑🏿‍🦯‍➡️"
            ],
            .manWithWhiteCane:[
                [.light]: "👨🏻‍🦯",
                [.mediumLight]: "👨🏼‍🦯",
                [.medium]: "👨🏽‍🦯",
                [.mediumDark]: "👨🏾‍🦯",
                [.dark]: "👨🏿‍🦯"
            ],
            .manWithWhiteCaneFacingRight:[
                [.light]: "👨🏻‍🦯‍➡️",
                [.mediumLight]: "👨🏼‍🦯‍➡️",
                [.medium]: "👨🏽‍🦯‍➡️",
                [.mediumDark]: "👨🏾‍🦯‍➡️",
                [.dark]: "👨🏿‍🦯‍➡️"
            ],
            .womanWithWhiteCane:[
                [.light]: "👩🏻‍🦯",
                [.mediumLight]: "👩🏼‍🦯",
                [.medium]: "👩🏽‍🦯",
                [.mediumDark]: "👩🏾‍🦯",
                [.dark]: "👩🏿‍🦯"
            ],
            .womanWithWhiteCaneFacingRight:[
                [.light]: "👩🏻‍🦯‍➡️",
                [.mediumLight]: "👩🏼‍🦯‍➡️",
                [.medium]: "👩🏽‍🦯‍➡️",
                [.mediumDark]: "👩🏾‍🦯‍➡️",
                [.dark]: "👩🏿‍🦯‍➡️"
            ],
            .personInMotorizedWheelchair:[
                [.light]: "🧑🏻‍🦼",
                [.mediumLight]: "🧑🏼‍🦼",
                [.medium]: "🧑🏽‍🦼",
                [.mediumDark]: "🧑🏾‍🦼",
                [.dark]: "🧑🏿‍🦼"
            ],
            .personInMotorizedWheelchairFacingRight:[
                [.light]: "🧑🏻‍🦼‍➡️",
                [.mediumLight]: "🧑🏼‍🦼‍➡️",
                [.medium]: "🧑🏽‍🦼‍➡️",
                [.mediumDark]: "🧑🏾‍🦼‍➡️",
                [.dark]: "🧑🏿‍🦼‍➡️"
            ],
            .manInMotorizedWheelchair:[
                [.light]: "👨🏻‍🦼",
                [.mediumLight]: "👨🏼‍🦼",
                [.medium]: "👨🏽‍🦼",
                [.mediumDark]: "👨🏾‍🦼",
                [.dark]: "👨🏿‍🦼"
            ],
            .manInMotorizedWheelchairFacingRight:[
                [.light]: "👨🏻‍🦼‍➡️",
                [.mediumLight]: "👨🏼‍🦼‍➡️",
                [.medium]: "👨🏽‍🦼‍➡️",
                [.mediumDark]: "👨🏾‍🦼‍➡️",
                [.dark]: "👨🏿‍🦼‍➡️"
            ],
            .womanInMotorizedWheelchair:[
                [.light]: "👩🏻‍🦼",
                [.mediumLight]: "👩🏼‍🦼",
                [.medium]: "👩🏽‍🦼",
                [.mediumDark]: "👩🏾‍🦼",
                [.dark]: "👩🏿‍🦼"
            ],
            .womanInMotorizedWheelchairFacingRight:[
                [.light]: "👩🏻‍🦼‍➡️",
                [.mediumLight]: "👩🏼‍🦼‍➡️",
                [.medium]: "👩🏽‍🦼‍➡️",
                [.mediumDark]: "👩🏾‍🦼‍➡️",
                [.dark]: "👩🏿‍🦼‍➡️"
            ],
            .personInManualWheelchair:[
                [.light]: "🧑🏻‍🦽",
                [.mediumLight]: "🧑🏼‍🦽",
                [.medium]: "🧑🏽‍🦽",
                [.mediumDark]: "🧑🏾‍🦽",
                [.dark]: "🧑🏿‍🦽"
            ],
            .personInManualWheelchairFacingRight:[
                [.light]: "🧑🏻‍🦽‍➡️",
                [.mediumLight]: "🧑🏼‍🦽‍➡️",
                [.medium]: "🧑🏽‍🦽‍➡️",
                [.mediumDark]: "🧑🏾‍🦽‍➡️",
                [.dark]: "🧑🏿‍🦽‍➡️"
            ],
            .manInManualWheelchair:[
                [.light]: "👨🏻‍🦽",
                [.mediumLight]: "👨🏼‍🦽",
                [.medium]: "👨🏽‍🦽",
                [.mediumDark]: "👨🏾‍🦽",
                [.dark]: "👨🏿‍🦽"
            ],
            .manInManualWheelchairFacingRight:[
                [.light]: "👨🏻‍🦽‍➡️",
                [.mediumLight]: "👨🏼‍🦽‍➡️",
                [.medium]: "👨🏽‍🦽‍➡️",
                [.mediumDark]: "👨🏾‍🦽‍➡️",
                [.dark]: "👨🏿‍🦽‍➡️"
            ],
            .womanInManualWheelchair:[
                [.light]: "👩🏻‍🦽",
                [.mediumLight]: "👩🏼‍🦽",
                [.medium]: "👩🏽‍🦽",
                [.mediumDark]: "👩🏾‍🦽",
                [.dark]: "👩🏿‍🦽"
            ],
            .womanInManualWheelchairFacingRight:[
                [.light]: "👩🏻‍🦽‍➡️",
                [.mediumLight]: "👩🏼‍🦽‍➡️",
                [.medium]: "👩🏽‍🦽‍➡️",
                [.mediumDark]: "👩🏾‍🦽‍➡️",
                [.dark]: "👩🏿‍🦽‍➡️"
            ],
            .personRunning:[
                [.light]: "🏃🏻",
                [.mediumLight]: "🏃🏼",
                [.medium]: "🏃🏽",
                [.mediumDark]: "🏃🏾",
                [.dark]: "🏃🏿"
            ],
            .manRunning:[
                [.light]: "🏃🏻‍♂️",
                [.mediumLight]: "🏃🏼‍♂️",
                [.medium]: "🏃🏽‍♂️",
                [.mediumDark]: "🏃🏾‍♂️",
                [.dark]: "🏃🏿‍♂️"
            ],
            .womanRunning:[
                [.light]: "🏃🏻‍♀️",
                [.mediumLight]: "🏃🏼‍♀️",
                [.medium]: "🏃🏽‍♀️",
                [.mediumDark]: "🏃🏾‍♀️",
                [.dark]: "🏃🏿‍♀️"
            ],
            .personRunningFacingRight:[
                [.light]: "🏃🏻‍➡️",
                [.mediumLight]: "🏃🏼‍➡️",
                [.medium]: "🏃🏽‍➡️",
                [.mediumDark]: "🏃🏾‍➡️",
                [.dark]: "🏃🏿‍➡️"
            ],
            .womanRunningFacingRight:[
                [.light]: "🏃🏻‍♀️‍➡️",
                [.mediumLight]: "🏃🏼‍♀️‍➡️",
                [.medium]: "🏃🏽‍♀️‍➡️",
                [.mediumDark]: "🏃🏾‍♀️‍➡️",
                [.dark]: "🏃🏿‍♀️‍➡️"
            ],
            .manRunningFacingRight:[
                [.light]: "🏃🏻‍♂️‍➡️",
                [.mediumLight]: "🏃🏼‍♂️‍➡️",
                [.medium]: "🏃🏽‍♂️‍➡️",
                [.mediumDark]: "🏃🏾‍♂️‍➡️",
                [.dark]: "🏃🏿‍♂️‍➡️"
            ],
            .womanDancing:[
                [.light]: "💃🏻",
                [.mediumLight]: "💃🏼",
                [.medium]: "💃🏽",
                [.mediumDark]: "💃🏾",
                [.dark]: "💃🏿"
            ],
            .manDancing:[
                [.light]: "🕺🏻",
                [.mediumLight]: "🕺🏼",
                [.medium]: "🕺🏽",
                [.mediumDark]: "🕺🏾",
                [.dark]: "🕺🏿"
            ],
            .personInSuitLevitating:[
                [.light]: "🕴🏻",
                [.mediumLight]: "🕴🏼",
                [.medium]: "🕴🏽",
                [.mediumDark]: "🕴🏾",
                [.dark]: "🕴🏿"
            ],
            .personInSteamyRoom:[
                [.light]: "🧖🏻",
                [.mediumLight]: "🧖🏼",
                [.medium]: "🧖🏽",
                [.mediumDark]: "🧖🏾",
                [.dark]: "🧖🏿"
            ],
            .manInSteamyRoom:[
                [.light]: "🧖🏻‍♂️",
                [.mediumLight]: "🧖🏼‍♂️",
                [.medium]: "🧖🏽‍♂️",
                [.mediumDark]: "🧖🏾‍♂️",
                [.dark]: "🧖🏿‍♂️"
            ],
            .womanInSteamyRoom:[
                [.light]: "🧖🏻‍♀️",
                [.mediumLight]: "🧖🏼‍♀️",
                [.medium]: "🧖🏽‍♀️",
                [.mediumDark]: "🧖🏾‍♀️",
                [.dark]: "🧖🏿‍♀️"
            ],
            .personClimbing:[
                [.light]: "🧗🏻",
                [.mediumLight]: "🧗🏼",
                [.medium]: "🧗🏽",
                [.mediumDark]: "🧗🏾",
                [.dark]: "🧗🏿"
            ],
            .manClimbing:[
                [.light]: "🧗🏻‍♂️",
                [.mediumLight]: "🧗🏼‍♂️",
                [.medium]: "🧗🏽‍♂️",
                [.mediumDark]: "🧗🏾‍♂️",
                [.dark]: "🧗🏿‍♂️"
            ],
            .womanClimbing:[
                [.light]: "🧗🏻‍♀️",
                [.mediumLight]: "🧗🏼‍♀️",
                [.medium]: "🧗🏽‍♀️",
                [.mediumDark]: "🧗🏾‍♀️",
                [.dark]: "🧗🏿‍♀️"
            ],
            .horseRacing:[
                [.light]: "🏇🏻",
                [.mediumLight]: "🏇🏼",
                [.medium]: "🏇🏽",
                [.mediumDark]: "🏇🏾",
                [.dark]: "🏇🏿"
            ],
            .snowboarder:[
                [.light]: "🏂🏻",
                [.mediumLight]: "🏂🏼",
                [.medium]: "🏂🏽",
                [.mediumDark]: "🏂🏾",
                [.dark]: "🏂🏿"
            ],
            .personGolfing:[
                [.light]: "🏌🏻",
                [.mediumLight]: "🏌🏼",
                [.medium]: "🏌🏽",
                [.mediumDark]: "🏌🏾",
                [.dark]: "🏌🏿"
            ],
            .manGolfing:[
                [.light]: "🏌🏻‍♂️",
                [.mediumLight]: "🏌🏼‍♂️",
                [.medium]: "🏌🏽‍♂️",
                [.mediumDark]: "🏌🏾‍♂️",
                [.dark]: "🏌🏿‍♂️"
            ],
            .womanGolfing:[
                [.light]: "🏌🏻‍♀️",
                [.mediumLight]: "🏌🏼‍♀️",
                [.medium]: "🏌🏽‍♀️",
                [.mediumDark]: "🏌🏾‍♀️",
                [.dark]: "🏌🏿‍♀️"
            ],
            .personSurfing:[
                [.light]: "🏄🏻",
                [.mediumLight]: "🏄🏼",
                [.medium]: "🏄🏽",
                [.mediumDark]: "🏄🏾",
                [.dark]: "🏄🏿"
            ],
            .manSurfing:[
                [.light]: "🏄🏻‍♂️",
                [.mediumLight]: "🏄🏼‍♂️",
                [.medium]: "🏄🏽‍♂️",
                [.mediumDark]: "🏄🏾‍♂️",
                [.dark]: "🏄🏿‍♂️"
            ],
            .womanSurfing:[
                [.light]: "🏄🏻‍♀️",
                [.mediumLight]: "🏄🏼‍♀️",
                [.medium]: "🏄🏽‍♀️",
                [.mediumDark]: "🏄🏾‍♀️",
                [.dark]: "🏄🏿‍♀️"
            ],
            .personRowingBoat:[
                [.light]: "🚣🏻",
                [.mediumLight]: "🚣🏼",
                [.medium]: "🚣🏽",
                [.mediumDark]: "🚣🏾",
                [.dark]: "🚣🏿"
            ],
            .manRowingBoat:[
                [.light]: "🚣🏻‍♂️",
                [.mediumLight]: "🚣🏼‍♂️",
                [.medium]: "🚣🏽‍♂️",
                [.mediumDark]: "🚣🏾‍♂️",
                [.dark]: "🚣🏿‍♂️"
            ],
            .womanRowingBoat:[
                [.light]: "🚣🏻‍♀️",
                [.mediumLight]: "🚣🏼‍♀️",
                [.medium]: "🚣🏽‍♀️",
                [.mediumDark]: "🚣🏾‍♀️",
                [.dark]: "🚣🏿‍♀️"
            ],
            .personSwimming:[
                [.light]: "🏊🏻",
                [.mediumLight]: "🏊🏼",
                [.medium]: "🏊🏽",
                [.mediumDark]: "🏊🏾",
                [.dark]: "🏊🏿"
            ],
            .manSwimming:[
                [.light]: "🏊🏻‍♂️",
                [.mediumLight]: "🏊🏼‍♂️",
                [.medium]: "🏊🏽‍♂️",
                [.mediumDark]: "🏊🏾‍♂️",
                [.dark]: "🏊🏿‍♂️"
            ],
            .womanSwimming:[
                [.light]: "🏊🏻‍♀️",
                [.mediumLight]: "🏊🏼‍♀️",
                [.medium]: "🏊🏽‍♀️",
                [.mediumDark]: "🏊🏾‍♀️",
                [.dark]: "🏊🏿‍♀️"
            ],
            .personBouncingBall:[
                [.light]: "⛹🏻",
                [.mediumLight]: "⛹🏼",
                [.medium]: "⛹🏽",
                [.mediumDark]: "⛹🏾",
                [.dark]: "⛹🏿"
            ],
            .manBouncingBall:[
                [.light]: "⛹🏻‍♂️",
                [.mediumLight]: "⛹🏼‍♂️",
                [.medium]: "⛹🏽‍♂️",
                [.mediumDark]: "⛹🏾‍♂️",
                [.dark]: "⛹🏿‍♂️"
            ],
            .womanBouncingBall:[
                [.light]: "⛹🏻‍♀️",
                [.mediumLight]: "⛹🏼‍♀️",
                [.medium]: "⛹🏽‍♀️",
                [.mediumDark]: "⛹🏾‍♀️",
                [.dark]: "⛹🏿‍♀️"
            ],
            .personLiftingWeights:[
                [.light]: "🏋🏻",
                [.mediumLight]: "🏋🏼",
                [.medium]: "🏋🏽",
                [.mediumDark]: "🏋🏾",
                [.dark]: "🏋🏿"
            ],
            .manLiftingWeights:[
                [.light]: "🏋🏻‍♂️",
                [.mediumLight]: "🏋🏼‍♂️",
                [.medium]: "🏋🏽‍♂️",
                [.mediumDark]: "🏋🏾‍♂️",
                [.dark]: "🏋🏿‍♂️"
            ],
            .womanLiftingWeights:[
                [.light]: "🏋🏻‍♀️",
                [.mediumLight]: "🏋🏼‍♀️",
                [.medium]: "🏋🏽‍♀️",
                [.mediumDark]: "🏋🏾‍♀️",
                [.dark]: "🏋🏿‍♀️"
            ],
            .personBiking:[
                [.light]: "🚴🏻",
                [.mediumLight]: "🚴🏼",
                [.medium]: "🚴🏽",
                [.mediumDark]: "🚴🏾",
                [.dark]: "🚴🏿"
            ],
            .manBiking:[
                [.light]: "🚴🏻‍♂️",
                [.mediumLight]: "🚴🏼‍♂️",
                [.medium]: "🚴🏽‍♂️",
                [.mediumDark]: "🚴🏾‍♂️",
                [.dark]: "🚴🏿‍♂️"
            ],
            .womanBiking:[
                [.light]: "🚴🏻‍♀️",
                [.mediumLight]: "🚴🏼‍♀️",
                [.medium]: "🚴🏽‍♀️",
                [.mediumDark]: "🚴🏾‍♀️",
                [.dark]: "🚴🏿‍♀️"
            ],
            .personMountainBiking:[
                [.light]: "🚵🏻",
                [.mediumLight]: "🚵🏼",
                [.medium]: "🚵🏽",
                [.mediumDark]: "🚵🏾",
                [.dark]: "🚵🏿"
            ],
            .manMountainBiking:[
                [.light]: "🚵🏻‍♂️",
                [.mediumLight]: "🚵🏼‍♂️",
                [.medium]: "🚵🏽‍♂️",
                [.mediumDark]: "🚵🏾‍♂️",
                [.dark]: "🚵🏿‍♂️"
            ],
            .womanMountainBiking:[
                [.light]: "🚵🏻‍♀️",
                [.mediumLight]: "🚵🏼‍♀️",
                [.medium]: "🚵🏽‍♀️",
                [.mediumDark]: "🚵🏾‍♀️",
                [.dark]: "🚵🏿‍♀️"
            ],
            .personCartwheeling:[
                [.light]: "🤸🏻",
                [.mediumLight]: "🤸🏼",
                [.medium]: "🤸🏽",
                [.mediumDark]: "🤸🏾",
                [.dark]: "🤸🏿"
            ],
            .manCartwheeling:[
                [.light]: "🤸🏻‍♂️",
                [.mediumLight]: "🤸🏼‍♂️",
                [.medium]: "🤸🏽‍♂️",
                [.mediumDark]: "🤸🏾‍♂️",
                [.dark]: "🤸🏿‍♂️"
            ],
            .womanCartwheeling:[
                [.light]: "🤸🏻‍♀️",
                [.mediumLight]: "🤸🏼‍♀️",
                [.medium]: "🤸🏽‍♀️",
                [.mediumDark]: "🤸🏾‍♀️",
                [.dark]: "🤸🏿‍♀️"
            ],
            .personPlayingWaterPolo:[
                [.light]: "🤽🏻",
                [.mediumLight]: "🤽🏼",
                [.medium]: "🤽🏽",
                [.mediumDark]: "🤽🏾",
                [.dark]: "🤽🏿"
            ],
            .manPlayingWaterPolo:[
                [.light]: "🤽🏻‍♂️",
                [.mediumLight]: "🤽🏼‍♂️",
                [.medium]: "🤽🏽‍♂️",
                [.mediumDark]: "🤽🏾‍♂️",
                [.dark]: "🤽🏿‍♂️"
            ],
            .womanPlayingWaterPolo:[
                [.light]: "🤽🏻‍♀️",
                [.mediumLight]: "🤽🏼‍♀️",
                [.medium]: "🤽🏽‍♀️",
                [.mediumDark]: "🤽🏾‍♀️",
                [.dark]: "🤽🏿‍♀️"
            ],
            .personPlayingHandball:[
                [.light]: "🤾🏻",
                [.mediumLight]: "🤾🏼",
                [.medium]: "🤾🏽",
                [.mediumDark]: "🤾🏾",
                [.dark]: "🤾🏿"
            ],
            .manPlayingHandball:[
                [.light]: "🤾🏻‍♂️",
                [.mediumLight]: "🤾🏼‍♂️",
                [.medium]: "🤾🏽‍♂️",
                [.mediumDark]: "🤾🏾‍♂️",
                [.dark]: "🤾🏿‍♂️"
            ],
            .womanPlayingHandball:[
                [.light]: "🤾🏻‍♀️",
                [.mediumLight]: "🤾🏼‍♀️",
                [.medium]: "🤾🏽‍♀️",
                [.mediumDark]: "🤾🏾‍♀️",
                [.dark]: "🤾🏿‍♀️"
            ],
            .personJuggling:[
                [.light]: "🤹🏻",
                [.mediumLight]: "🤹🏼",
                [.medium]: "🤹🏽",
                [.mediumDark]: "🤹🏾",
                [.dark]: "🤹🏿"
            ],
            .manJuggling:[
                [.light]: "🤹🏻‍♂️",
                [.mediumLight]: "🤹🏼‍♂️",
                [.medium]: "🤹🏽‍♂️",
                [.mediumDark]: "🤹🏾‍♂️",
                [.dark]: "🤹🏿‍♂️"
            ],
            .womanJuggling:[
                [.light]: "🤹🏻‍♀️",
                [.mediumLight]: "🤹🏼‍♀️",
                [.medium]: "🤹🏽‍♀️",
                [.mediumDark]: "🤹🏾‍♀️",
                [.dark]: "🤹🏿‍♀️"
            ],
            .personInLotusPosition:[
                [.light]: "🧘🏻",
                [.mediumLight]: "🧘🏼",
                [.medium]: "🧘🏽",
                [.mediumDark]: "🧘🏾",
                [.dark]: "🧘🏿"
            ],
            .manInLotusPosition:[
                [.light]: "🧘🏻‍♂️",
                [.mediumLight]: "🧘🏼‍♂️",
                [.medium]: "🧘🏽‍♂️",
                [.mediumDark]: "🧘🏾‍♂️",
                [.dark]: "🧘🏿‍♂️"
            ],
            .womanInLotusPosition:[
                [.light]: "🧘🏻‍♀️",
                [.mediumLight]: "🧘🏼‍♀️",
                [.medium]: "🧘🏽‍♀️",
                [.mediumDark]: "🧘🏾‍♀️",
                [.dark]: "🧘🏿‍♀️"
            ],
            .personTakingBath:[
                [.light]: "🛀🏻",
                [.mediumLight]: "🛀🏼",
                [.medium]: "🛀🏽",
                [.mediumDark]: "🛀🏾",
                [.dark]: "🛀🏿"
            ],
            .personInBed:[
                [.light]: "🛌🏻",
                [.mediumLight]: "🛌🏼",
                [.medium]: "🛌🏽",
                [.mediumDark]: "🛌🏾",
                [.dark]: "🛌🏿"
            ],
            .peopleHoldingHands:[
                [.light]: "🧑🏻‍🤝‍🧑🏻",
                [.light, .mediumLight]: "🧑🏻‍🤝‍🧑🏼",
                [.light, .medium]: "🧑🏻‍🤝‍🧑🏽",
                [.light, .mediumDark]: "🧑🏻‍🤝‍🧑🏾",
                [.light, .dark]: "🧑🏻‍🤝‍🧑🏿",
                [.mediumLight, .light]: "🧑🏼‍🤝‍🧑🏻",
                [.mediumLight]: "🧑🏼‍🤝‍🧑🏼",
                [.mediumLight, .medium]: "🧑🏼‍🤝‍🧑🏽",
                [.mediumLight, .mediumDark]: "🧑🏼‍🤝‍🧑🏾",
                [.mediumLight, .dark]: "🧑🏼‍🤝‍🧑🏿",
                [.medium, .light]: "🧑🏽‍🤝‍🧑🏻",
                [.medium, .mediumLight]: "🧑🏽‍🤝‍🧑🏼",
                [.medium]: "🧑🏽‍🤝‍🧑🏽",
                [.medium, .mediumDark]: "🧑🏽‍🤝‍🧑🏾",
                [.medium, .dark]: "🧑🏽‍🤝‍🧑🏿",
                [.mediumDark, .light]: "🧑🏾‍🤝‍🧑🏻",
                [.mediumDark, .mediumLight]: "🧑🏾‍🤝‍🧑🏼",
                [.mediumDark, .medium]: "🧑🏾‍🤝‍🧑🏽",
                [.mediumDark]: "🧑🏾‍🤝‍🧑🏾",
                [.mediumDark, .dark]: "🧑🏾‍🤝‍🧑🏿",
                [.dark, .light]: "🧑🏿‍🤝‍🧑🏻",
                [.dark, .mediumLight]: "🧑🏿‍🤝‍🧑🏼",
                [.dark, .medium]: "🧑🏿‍🤝‍🧑🏽",
                [.dark, .mediumDark]: "🧑🏿‍🤝‍🧑🏾",
                [.dark]: "🧑🏿‍🤝‍🧑🏿"
            ],
            .womenHoldingHands:[
                [.light]: "👭🏻",
                [.light, .mediumLight]: "👩🏻‍🤝‍👩🏼",
                [.light, .medium]: "👩🏻‍🤝‍👩🏽",
                [.light, .mediumDark]: "👩🏻‍🤝‍👩🏾",
                [.light, .dark]: "👩🏻‍🤝‍👩🏿",
                [.mediumLight, .light]: "👩🏼‍🤝‍👩🏻",
                [.mediumLight]: "👭🏼",
                [.mediumLight, .medium]: "👩🏼‍🤝‍👩🏽",
                [.mediumLight, .mediumDark]: "👩🏼‍🤝‍👩🏾",
                [.mediumLight, .dark]: "👩🏼‍🤝‍👩🏿",
                [.medium, .light]: "👩🏽‍🤝‍👩🏻",
                [.medium, .mediumLight]: "👩🏽‍🤝‍👩🏼",
                [.medium]: "👭🏽",
                [.medium, .mediumDark]: "👩🏽‍🤝‍👩🏾",
                [.medium, .dark]: "👩🏽‍🤝‍👩🏿",
                [.mediumDark, .light]: "👩🏾‍🤝‍👩🏻",
                [.mediumDark, .mediumLight]: "👩🏾‍🤝‍👩🏼",
                [.mediumDark, .medium]: "👩🏾‍🤝‍👩🏽",
                [.mediumDark]: "👭🏾",
                [.mediumDark, .dark]: "👩🏾‍🤝‍👩🏿",
                [.dark, .light]: "👩🏿‍🤝‍👩🏻",
                [.dark, .mediumLight]: "👩🏿‍🤝‍👩🏼",
                [.dark, .medium]: "👩🏿‍🤝‍👩🏽",
                [.dark, .mediumDark]: "👩🏿‍🤝‍👩🏾",
                [.dark]: "👭🏿"
            ],
            .womanAndManHoldingHands:[
                [.light]: "👫🏻",
                [.light, .mediumLight]: "👩🏻‍🤝‍👨🏼",
                [.light, .medium]: "👩🏻‍🤝‍👨🏽",
                [.light, .mediumDark]: "👩🏻‍🤝‍👨🏾",
                [.light, .dark]: "👩🏻‍🤝‍👨🏿",
                [.mediumLight, .light]: "👩🏼‍🤝‍👨🏻",
                [.mediumLight]: "👫🏼",
                [.mediumLight, .medium]: "👩🏼‍🤝‍👨🏽",
                [.mediumLight, .mediumDark]: "👩🏼‍🤝‍👨🏾",
                [.mediumLight, .dark]: "👩🏼‍🤝‍👨🏿",
                [.medium, .light]: "👩🏽‍🤝‍👨🏻",
                [.medium, .mediumLight]: "👩🏽‍🤝‍👨🏼",
                [.medium]: "👫🏽",
                [.medium, .mediumDark]: "👩🏽‍🤝‍👨🏾",
                [.medium, .dark]: "👩🏽‍🤝‍👨🏿",
                [.mediumDark, .light]: "👩🏾‍🤝‍👨🏻",
                [.mediumDark, .mediumLight]: "👩🏾‍🤝‍👨🏼",
                [.mediumDark, .medium]: "👩🏾‍🤝‍👨🏽",
                [.mediumDark]: "👫🏾",
                [.mediumDark, .dark]: "👩🏾‍🤝‍👨🏿",
                [.dark, .light]: "👩🏿‍🤝‍👨🏻",
                [.dark, .mediumLight]: "👩🏿‍🤝‍👨🏼",
                [.dark, .medium]: "👩🏿‍🤝‍👨🏽",
                [.dark, .mediumDark]: "👩🏿‍🤝‍👨🏾",
                [.dark]: "👫🏿"
            ],
            .menHoldingHands:[
                [.light]: "👬🏻",
                [.light, .mediumLight]: "👨🏻‍🤝‍👨🏼",
                [.light, .medium]: "👨🏻‍🤝‍👨🏽",
                [.light, .mediumDark]: "👨🏻‍🤝‍👨🏾",
                [.light, .dark]: "👨🏻‍🤝‍👨🏿",
                [.mediumLight, .light]: "👨🏼‍🤝‍👨🏻",
                [.mediumLight]: "👬🏼",
                [.mediumLight, .medium]: "👨🏼‍🤝‍👨🏽",
                [.mediumLight, .mediumDark]: "👨🏼‍🤝‍👨🏾",
                [.mediumLight, .dark]: "👨🏼‍🤝‍👨🏿",
                [.medium, .light]: "👨🏽‍🤝‍👨🏻",
                [.medium, .mediumLight]: "👨🏽‍🤝‍👨🏼",
                [.medium]: "👬🏽",
                [.medium, .mediumDark]: "👨🏽‍🤝‍👨🏾",
                [.medium, .dark]: "👨🏽‍🤝‍👨🏿",
                [.mediumDark, .light]: "👨🏾‍🤝‍👨🏻",
                [.mediumDark, .mediumLight]: "👨🏾‍🤝‍👨🏼",
                [.mediumDark, .medium]: "👨🏾‍🤝‍👨🏽",
                [.mediumDark]: "👬🏾",
                [.mediumDark, .dark]: "👨🏾‍🤝‍👨🏿",
                [.dark, .light]: "👨🏿‍🤝‍👨🏻",
                [.dark, .mediumLight]: "👨🏿‍🤝‍👨🏼",
                [.dark, .medium]: "👨🏿‍🤝‍👨🏽",
                [.dark, .mediumDark]: "👨🏿‍🤝‍👨🏾",
                [.dark]: "👬🏿"
            ],
            .kiss:[
                [.light]: "💏🏻",
                [.mediumLight]: "💏🏼",
                [.medium]: "💏🏽",
                [.mediumDark]: "💏🏾",
                [.dark]: "💏🏿",
                [.light, .mediumLight]: "🧑🏻‍❤️‍💋‍🧑🏼",
                [.light, .medium]: "🧑🏻‍❤️‍💋‍🧑🏽",
                [.light, .mediumDark]: "🧑🏻‍❤️‍💋‍🧑🏾",
                [.light, .dark]: "🧑🏻‍❤️‍💋‍🧑🏿",
                [.mediumLight, .light]: "🧑🏼‍❤️‍💋‍🧑🏻",
                [.mediumLight, .medium]: "🧑🏼‍❤️‍💋‍🧑🏽",
                [.mediumLight, .mediumDark]: "🧑🏼‍❤️‍💋‍🧑🏾",
                [.mediumLight, .dark]: "🧑🏼‍❤️‍💋‍🧑🏿",
                [.medium, .light]: "🧑🏽‍❤️‍💋‍🧑🏻",
                [.medium, .mediumLight]: "🧑🏽‍❤️‍💋‍🧑🏼",
                [.medium, .mediumDark]: "🧑🏽‍❤️‍💋‍🧑🏾",
                [.medium, .dark]: "🧑🏽‍❤️‍💋‍🧑🏿",
                [.mediumDark, .light]: "🧑🏾‍❤️‍💋‍🧑🏻",
                [.mediumDark, .mediumLight]: "🧑🏾‍❤️‍💋‍🧑🏼",
                [.mediumDark, .medium]: "🧑🏾‍❤️‍💋‍🧑🏽",
                [.mediumDark, .dark]: "🧑🏾‍❤️‍💋‍🧑🏿",
                [.dark, .light]: "🧑🏿‍❤️‍💋‍🧑🏻",
                [.dark, .mediumLight]: "🧑🏿‍❤️‍💋‍🧑🏼",
                [.dark, .medium]: "🧑🏿‍❤️‍💋‍🧑🏽",
                [.dark, .mediumDark]: "🧑🏿‍❤️‍💋‍🧑🏾"
            ],
            .kissWomanMan:[
                [.light]: "👩🏻‍❤️‍💋‍👨🏻",
                [.light, .mediumLight]: "👩🏻‍❤️‍💋‍👨🏼",
                [.light, .medium]: "👩🏻‍❤️‍💋‍👨🏽",
                [.light, .mediumDark]: "👩🏻‍❤️‍💋‍👨🏾",
                [.light, .dark]: "👩🏻‍❤️‍💋‍👨🏿",
                [.mediumLight, .light]: "👩🏼‍❤️‍💋‍👨🏻",
                [.mediumLight]: "👩🏼‍❤️‍💋‍👨🏼",
                [.mediumLight, .medium]: "👩🏼‍❤️‍💋‍👨🏽",
                [.mediumLight, .mediumDark]: "👩🏼‍❤️‍💋‍👨🏾",
                [.mediumLight, .dark]: "👩🏼‍❤️‍💋‍👨🏿",
                [.medium, .light]: "👩🏽‍❤️‍💋‍👨🏻",
                [.medium, .mediumLight]: "👩🏽‍❤️‍💋‍👨🏼",
                [.medium]: "👩🏽‍❤️‍💋‍👨🏽",
                [.medium, .mediumDark]: "👩🏽‍❤️‍💋‍👨🏾",
                [.medium, .dark]: "👩🏽‍❤️‍💋‍👨🏿",
                [.mediumDark, .light]: "👩🏾‍❤️‍💋‍👨🏻",
                [.mediumDark, .mediumLight]: "👩🏾‍❤️‍💋‍👨🏼",
                [.mediumDark, .medium]: "👩🏾‍❤️‍💋‍👨🏽",
                [.mediumDark]: "👩🏾‍❤️‍💋‍👨🏾",
                [.mediumDark, .dark]: "👩🏾‍❤️‍💋‍👨🏿",
                [.dark, .light]: "👩🏿‍❤️‍💋‍👨🏻",
                [.dark, .mediumLight]: "👩🏿‍❤️‍💋‍👨🏼",
                [.dark, .medium]: "👩🏿‍❤️‍💋‍👨🏽",
                [.dark, .mediumDark]: "👩🏿‍❤️‍💋‍👨🏾",
                [.dark]: "👩🏿‍❤️‍💋‍👨🏿"
            ],
            .kissManMan:[
                [.light]: "👨🏻‍❤️‍💋‍👨🏻",
                [.light, .mediumLight]: "👨🏻‍❤️‍💋‍👨🏼",
                [.light, .medium]: "👨🏻‍❤️‍💋‍👨🏽",
                [.light, .mediumDark]: "👨🏻‍❤️‍💋‍👨🏾",
                [.light, .dark]: "👨🏻‍❤️‍💋‍👨🏿",
                [.mediumLight, .light]: "👨🏼‍❤️‍💋‍👨🏻",
                [.mediumLight]: "👨🏼‍❤️‍💋‍👨🏼",
                [.mediumLight, .medium]: "👨🏼‍❤️‍💋‍👨🏽",
                [.mediumLight, .mediumDark]: "👨🏼‍❤️‍💋‍👨🏾",
                [.mediumLight, .dark]: "👨🏼‍❤️‍💋‍👨🏿",
                [.medium, .light]: "👨🏽‍❤️‍💋‍👨🏻",
                [.medium, .mediumLight]: "👨🏽‍❤️‍💋‍👨🏼",
                [.medium]: "👨🏽‍❤️‍💋‍👨🏽",
                [.medium, .mediumDark]: "👨🏽‍❤️‍💋‍👨🏾",
                [.medium, .dark]: "👨🏽‍❤️‍💋‍👨🏿",
                [.mediumDark, .light]: "👨🏾‍❤️‍💋‍👨🏻",
                [.mediumDark, .mediumLight]: "👨🏾‍❤️‍💋‍👨🏼",
                [.mediumDark, .medium]: "👨🏾‍❤️‍💋‍👨🏽",
                [.mediumDark]: "👨🏾‍❤️‍💋‍👨🏾",
                [.mediumDark, .dark]: "👨🏾‍❤️‍💋‍👨🏿",
                [.dark, .light]: "👨🏿‍❤️‍💋‍👨🏻",
                [.dark, .mediumLight]: "👨🏿‍❤️‍💋‍👨🏼",
                [.dark, .medium]: "👨🏿‍❤️‍💋‍👨🏽",
                [.dark, .mediumDark]: "👨🏿‍❤️‍💋‍👨🏾",
                [.dark]: "👨🏿‍❤️‍💋‍👨🏿"
            ],
            .kissWomanWoman:[
                [.light]: "👩🏻‍❤️‍💋‍👩🏻",
                [.light, .mediumLight]: "👩🏻‍❤️‍💋‍👩🏼",
                [.light, .medium]: "👩🏻‍❤️‍💋‍👩🏽",
                [.light, .mediumDark]: "👩🏻‍❤️‍💋‍👩🏾",
                [.light, .dark]: "👩🏻‍❤️‍💋‍👩🏿",
                [.mediumLight, .light]: "👩🏼‍❤️‍💋‍👩🏻",
                [.mediumLight]: "👩🏼‍❤️‍💋‍👩🏼",
                [.mediumLight, .medium]: "👩🏼‍❤️‍💋‍👩🏽",
                [.mediumLight, .mediumDark]: "👩🏼‍❤️‍💋‍👩🏾",
                [.mediumLight, .dark]: "👩🏼‍❤️‍💋‍👩🏿",
                [.medium, .light]: "👩🏽‍❤️‍💋‍👩🏻",
                [.medium, .mediumLight]: "👩🏽‍❤️‍💋‍👩🏼",
                [.medium]: "👩🏽‍❤️‍💋‍👩🏽",
                [.medium, .mediumDark]: "👩🏽‍❤️‍💋‍👩🏾",
                [.medium, .dark]: "👩🏽‍❤️‍💋‍👩🏿",
                [.mediumDark, .light]: "👩🏾‍❤️‍💋‍👩🏻",
                [.mediumDark, .mediumLight]: "👩🏾‍❤️‍💋‍👩🏼",
                [.mediumDark, .medium]: "👩🏾‍❤️‍💋‍👩🏽",
                [.mediumDark]: "👩🏾‍❤️‍💋‍👩🏾",
                [.mediumDark, .dark]: "👩🏾‍❤️‍💋‍👩🏿",
                [.dark, .light]: "👩🏿‍❤️‍💋‍👩🏻",
                [.dark, .mediumLight]: "👩🏿‍❤️‍💋‍👩🏼",
                [.dark, .medium]: "👩🏿‍❤️‍💋‍👩🏽",
                [.dark, .mediumDark]: "👩🏿‍❤️‍💋‍👩🏾",
                [.dark]: "👩🏿‍❤️‍💋‍👩🏿"
            ],
            .coupleWithHeart:[
                [.light]: "💑🏻",
                [.mediumLight]: "💑🏼",
                [.medium]: "💑🏽",
                [.mediumDark]: "💑🏾",
                [.dark]: "💑🏿",
                [.light, .mediumLight]: "🧑🏻‍❤️‍🧑🏼",
                [.light, .medium]: "🧑🏻‍❤️‍🧑🏽",
                [.light, .mediumDark]: "🧑🏻‍❤️‍🧑🏾",
                [.light, .dark]: "🧑🏻‍❤️‍🧑🏿",
                [.mediumLight, .light]: "🧑🏼‍❤️‍🧑🏻",
                [.mediumLight, .medium]: "🧑🏼‍❤️‍🧑🏽",
                [.mediumLight, .mediumDark]: "🧑🏼‍❤️‍🧑🏾",
                [.mediumLight, .dark]: "🧑🏼‍❤️‍🧑🏿",
                [.medium, .light]: "🧑🏽‍❤️‍🧑🏻",
                [.medium, .mediumLight]: "🧑🏽‍❤️‍🧑🏼",
                [.medium, .mediumDark]: "🧑🏽‍❤️‍🧑🏾",
                [.medium, .dark]: "🧑🏽‍❤️‍🧑🏿",
                [.mediumDark, .light]: "🧑🏾‍❤️‍🧑🏻",
                [.mediumDark, .mediumLight]: "🧑🏾‍❤️‍🧑🏼",
                [.mediumDark, .medium]: "🧑🏾‍❤️‍🧑🏽",
                [.mediumDark, .dark]: "🧑🏾‍❤️‍🧑🏿",
                [.dark, .light]: "🧑🏿‍❤️‍🧑🏻",
                [.dark, .mediumLight]: "🧑🏿‍❤️‍🧑🏼",
                [.dark, .medium]: "🧑🏿‍❤️‍🧑🏽",
                [.dark, .mediumDark]: "🧑🏿‍❤️‍🧑🏾"
            ],
            .coupleWithHeartWomanMan:[
                [.light]: "👩🏻‍❤️‍👨🏻",
                [.light, .mediumLight]: "👩🏻‍❤️‍👨🏼",
                [.light, .medium]: "👩🏻‍❤️‍👨🏽",
                [.light, .mediumDark]: "👩🏻‍❤️‍👨🏾",
                [.light, .dark]: "👩🏻‍❤️‍👨🏿",
                [.mediumLight, .light]: "👩🏼‍❤️‍👨🏻",
                [.mediumLight]: "👩🏼‍❤️‍👨🏼",
                [.mediumLight, .medium]: "👩🏼‍❤️‍👨🏽",
                [.mediumLight, .mediumDark]: "👩🏼‍❤️‍👨🏾",
                [.mediumLight, .dark]: "👩🏼‍❤️‍👨🏿",
                [.medium, .light]: "👩🏽‍❤️‍👨🏻",
                [.medium, .mediumLight]: "👩🏽‍❤️‍👨🏼",
                [.medium]: "👩🏽‍❤️‍👨🏽",
                [.medium, .mediumDark]: "👩🏽‍❤️‍👨🏾",
                [.medium, .dark]: "👩🏽‍❤️‍👨🏿",
                [.mediumDark, .light]: "👩🏾‍❤️‍👨🏻",
                [.mediumDark, .mediumLight]: "👩🏾‍❤️‍👨🏼",
                [.mediumDark, .medium]: "👩🏾‍❤️‍👨🏽",
                [.mediumDark]: "👩🏾‍❤️‍👨🏾",
                [.mediumDark, .dark]: "👩🏾‍❤️‍👨🏿",
                [.dark, .light]: "👩🏿‍❤️‍👨🏻",
                [.dark, .mediumLight]: "👩🏿‍❤️‍👨🏼",
                [.dark, .medium]: "👩🏿‍❤️‍👨🏽",
                [.dark, .mediumDark]: "👩🏿‍❤️‍👨🏾",
                [.dark]: "👩🏿‍❤️‍👨🏿"
            ],
            .coupleWithHeartManMan:[
                [.light]: "👨🏻‍❤️‍👨🏻",
                [.light, .mediumLight]: "👨🏻‍❤️‍👨🏼",
                [.light, .medium]: "👨🏻‍❤️‍👨🏽",
                [.light, .mediumDark]: "👨🏻‍❤️‍👨🏾",
                [.light, .dark]: "👨🏻‍❤️‍👨🏿",
                [.mediumLight, .light]: "👨🏼‍❤️‍👨🏻",
                [.mediumLight]: "👨🏼‍❤️‍👨🏼",
                [.mediumLight, .medium]: "👨🏼‍❤️‍👨🏽",
                [.mediumLight, .mediumDark]: "👨🏼‍❤️‍👨🏾",
                [.mediumLight, .dark]: "👨🏼‍❤️‍👨🏿",
                [.medium, .light]: "👨🏽‍❤️‍👨🏻",
                [.medium, .mediumLight]: "👨🏽‍❤️‍👨🏼",
                [.medium]: "👨🏽‍❤️‍👨🏽",
                [.medium, .mediumDark]: "👨🏽‍❤️‍👨🏾",
                [.medium, .dark]: "👨🏽‍❤️‍👨🏿",
                [.mediumDark, .light]: "👨🏾‍❤️‍👨🏻",
                [.mediumDark, .mediumLight]: "👨🏾‍❤️‍👨🏼",
                [.mediumDark, .medium]: "👨🏾‍❤️‍👨🏽",
                [.mediumDark]: "👨🏾‍❤️‍👨🏾",
                [.mediumDark, .dark]: "👨🏾‍❤️‍👨🏿",
                [.dark, .light]: "👨🏿‍❤️‍👨🏻",
                [.dark, .mediumLight]: "👨🏿‍❤️‍👨🏼",
                [.dark, .medium]: "👨🏿‍❤️‍👨🏽",
                [.dark, .mediumDark]: "👨🏿‍❤️‍👨🏾",
                [.dark]: "👨🏿‍❤️‍👨🏿"
            ],
            .coupleWithHeartWomanWoman:[
                [.light]: "👩🏻‍❤️‍👩🏻",
                [.light, .mediumLight]: "👩🏻‍❤️‍👩🏼",
                [.light, .medium]: "👩🏻‍❤️‍👩🏽",
                [.light, .mediumDark]: "👩🏻‍❤️‍👩🏾",
                [.light, .dark]: "👩🏻‍❤️‍👩🏿",
                [.mediumLight, .light]: "👩🏼‍❤️‍👩🏻",
                [.mediumLight]: "👩🏼‍❤️‍👩🏼",
                [.mediumLight, .medium]: "👩🏼‍❤️‍👩🏽",
                [.mediumLight, .mediumDark]: "👩🏼‍❤️‍👩🏾",
                [.mediumLight, .dark]: "👩🏼‍❤️‍👩🏿",
                [.medium, .light]: "👩🏽‍❤️‍👩🏻",
                [.medium, .mediumLight]: "👩🏽‍❤️‍👩🏼",
                [.medium]: "👩🏽‍❤️‍👩🏽",
                [.medium, .mediumDark]: "👩🏽‍❤️‍👩🏾",
                [.medium, .dark]: "👩🏽‍❤️‍👩🏿",
                [.mediumDark, .light]: "👩🏾‍❤️‍👩🏻",
                [.mediumDark, .mediumLight]: "👩🏾‍❤️‍👩🏼",
                [.mediumDark, .medium]: "👩🏾‍❤️‍👩🏽",
                [.mediumDark]: "👩🏾‍❤️‍👩🏾",
                [.mediumDark, .dark]: "👩🏾‍❤️‍👩🏿",
                [.dark, .light]: "👩🏿‍❤️‍👩🏻",
                [.dark, .mediumLight]: "👩🏿‍❤️‍👩🏼",
                [.dark, .medium]: "👩🏿‍❤️‍👩🏽",
                [.dark, .mediumDark]: "👩🏿‍❤️‍👩🏾",
                [.dark]: "👩🏿‍❤️‍👩🏿"
            ]
        ]
    }()

    public var variants: [[SkinTone]: String]? {
        Emoji.allVariants[self]
    }
    public var version: Double {
      switch self {
       case .grinningFace:
            1.0
       case .grinningFaceWithBigEyes:
            0.6
       case .grinningFaceWithSmilingEyes:
            0.6
       case .beamingFaceWithSmilingEyes:
            0.6
       case .grinningSquintingFace:
            0.6
       case .grinningFaceWithSweat:
            0.6
       case .rollingOnTheFloorLaughing:
            3.0
       case .faceWithTearsOfJoy:
            0.6
       case .slightlySmilingFace:
            1.0
       case .upsideDownFace:
            1.0
       case .meltingFace:
            14.0
       case .winkingFace:
            0.6
       case .smilingFaceWithSmilingEyes:
            0.6
       case .smilingFaceWithHalo:
            1.0
       case .smilingFaceWithHearts:
            11.0
       case .smilingFaceWithHeartEyes:
            0.6
       case .starStruck:
            5.0
       case .faceBlowingAKiss:
            0.6
       case .kissingFace:
            1.0
       case .smilingFace:
            0.6
       case .kissingFaceWithClosedEyes:
            0.6
       case .kissingFaceWithSmilingEyes:
            1.0
       case .smilingFaceWithTear:
            13.0
       case .faceSavoringFood:
            0.6
       case .faceWithTongue:
            1.0
       case .winkingFaceWithTongue:
            0.6
       case .zanyFace:
            5.0
       case .squintingFaceWithTongue:
            0.6
       case .moneyMouthFace:
            1.0
       case .smilingFaceWithOpenHands:
            1.0
       case .faceWithHandOverMouth:
            5.0
       case .faceWithOpenEyesAndHandOverMouth:
            14.0
       case .faceWithPeekingEye:
            14.0
       case .shushingFace:
            5.0
       case .thinkingFace:
            1.0
       case .salutingFace:
            14.0
       case .zipperMouthFace:
            1.0
       case .faceWithRaisedEyebrow:
            5.0
       case .neutralFace:
            0.7
       case .expressionlessFace:
            1.0
       case .faceWithoutMouth:
            1.0
       case .dottedLineFace:
            14.0
       case .faceInClouds:
            13.1
       case .smirkingFace:
            0.6
       case .unamusedFace:
            0.6
       case .faceWithRollingEyes:
            1.0
       case .grimacingFace:
            1.0
       case .faceExhaling:
            13.1
       case .lyingFace:
            3.0
       case .shakingFace:
            15.0
       case .headShakingHorizontally:
            15.1
       case .headShakingVertically:
            15.1
       case .relievedFace:
            0.6
       case .pensiveFace:
            0.6
       case .sleepyFace:
            0.6
       case .droolingFace:
            3.0
       case .sleepingFace:
            1.0
       case .faceWithBagsUnderEyes:
            16.0
       case .faceWithMedicalMask:
            0.6
       case .faceWithThermometer:
            1.0
       case .faceWithHeadBandage:
            1.0
       case .nauseatedFace:
            3.0
       case .faceVomiting:
            5.0
       case .sneezingFace:
            3.0
       case .hotFace:
            11.0
       case .coldFace:
            11.0
       case .woozyFace:
            11.0
       case .faceWithCrossedOutEyes:
            0.6
       case .faceWithSpiralEyes:
            13.1
       case .explodingHead:
            5.0
       case .cowboyHatFace:
            3.0
       case .partyingFace:
            11.0
       case .disguisedFace:
            13.0
       case .smilingFaceWithSunglasses:
            1.0
       case .nerdFace:
            1.0
       case .faceWithMonocle:
            5.0
       case .confusedFace:
            1.0
       case .faceWithDiagonalMouth:
            14.0
       case .worriedFace:
            1.0
       case .slightlyFrowningFace:
            1.0
       case .frowningFace:
            0.7
       case .faceWithOpenMouth:
            1.0
       case .hushedFace:
            1.0
       case .astonishedFace:
            0.6
       case .flushedFace:
            0.6
       case .pleadingFace:
            11.0
       case .faceHoldingBackTears:
            14.0
       case .frowningFaceWithOpenMouth:
            1.0
       case .anguishedFace:
            1.0
       case .fearfulFace:
            0.6
       case .anxiousFaceWithSweat:
            0.6
       case .sadButRelievedFace:
            0.6
       case .cryingFace:
            0.6
       case .loudlyCryingFace:
            0.6
       case .faceScreamingInFear:
            0.6
       case .confoundedFace:
            0.6
       case .perseveringFace:
            0.6
       case .disappointedFace:
            0.6
       case .downcastFaceWithSweat:
            0.6
       case .wearyFace:
            0.6
       case .tiredFace:
            0.6
       case .yawningFace:
            12.0
       case .faceWithSteamFromNose:
            0.6
       case .enragedFace:
            0.6
       case .angryFace:
            0.6
       case .faceWithSymbolsOnMouth:
            5.0
       case .smilingFaceWithHorns:
            1.0
       case .angryFaceWithHorns:
            0.6
       case .skull:
            0.6
       case .skullAndCrossbones:
            1.0
       case .pileOfPoo:
            0.6
       case .clownFace:
            3.0
       case .ogre:
            0.6
       case .goblin:
            0.6
       case .ghost:
            0.6
       case .alien:
            0.6
       case .alienMonster:
            0.6
       case .robot:
            1.0
       case .grinningCat:
            0.6
       case .grinningCatWithSmilingEyes:
            0.6
       case .catWithTearsOfJoy:
            0.6
       case .smilingCatWithHeartEyes:
            0.6
       case .catWithWrySmile:
            0.6
       case .kissingCat:
            0.6
       case .wearyCat:
            0.6
       case .cryingCat:
            0.6
       case .poutingCat:
            0.6
       case .seeNoEvilMonkey:
            0.6
       case .hearNoEvilMonkey:
            0.6
       case .speakNoEvilMonkey:
            0.6
       case .loveLetter:
            0.6
       case .heartWithArrow:
            0.6
       case .heartWithRibbon:
            0.6
       case .sparklingHeart:
            0.6
       case .growingHeart:
            0.6
       case .beatingHeart:
            0.6
       case .revolvingHearts:
            0.6
       case .twoHearts:
            0.6
       case .heartDecoration:
            0.6
       case .heartExclamation:
            1.0
       case .brokenHeart:
            0.6
       case .heartOnFire:
            13.1
       case .mendingHeart:
            13.1
       case .redHeart:
            0.6
       case .pinkHeart:
            15.0
       case .orangeHeart:
            5.0
       case .yellowHeart:
            0.6
       case .greenHeart:
            0.6
       case .blueHeart:
            0.6
       case .lightBlueHeart:
            15.0
       case .purpleHeart:
            0.6
       case .brownHeart:
            12.0
       case .blackHeart:
            3.0
       case .greyHeart:
            15.0
       case .whiteHeart:
            12.0
       case .kissMark:
            0.6
       case .hundredPoints:
            0.6
       case .angerSymbol:
            0.6
       case .collision:
            0.6
       case .dizzy:
            0.6
       case .sweatDroplets:
            0.6
       case .dashingAway:
            0.6
       case .hole:
            0.7
       case .speechBalloon:
            0.6
       case .eyeInSpeechBubble:
            2.0
       case .leftSpeechBubble:
            2.0
       case .rightAngerBubble:
            0.7
       case .thoughtBalloon:
            1.0
       case .zzz:
            0.6
       case .wavingHand:
            0.6
       case .raisedBackOfHand:
            3.0
       case .handWithFingersSplayed:
            0.7
       case .raisedHand:
            0.6
       case .vulcanSalute:
            1.0
       case .rightwardsHand:
            14.0
       case .leftwardsHand:
            14.0
       case .palmDownHand:
            14.0
       case .palmUpHand:
            14.0
       case .leftwardsPushingHand:
            15.0
       case .rightwardsPushingHand:
            15.0
       case .okHand:
            0.6
       case .pinchedFingers:
            13.0
       case .pinchingHand:
            12.0
       case .victoryHand:
            0.6
       case .crossedFingers:
            3.0
       case .handWithIndexFingerAndThumbCrossed:
            14.0
       case .loveYouGesture:
            5.0
       case .signOfTheHorns:
            1.0
       case .callMeHand:
            3.0
       case .backhandIndexPointingLeft:
            0.6
       case .backhandIndexPointingRight:
            0.6
       case .backhandIndexPointingUp:
            0.6
       case .middleFinger:
            1.0
       case .backhandIndexPointingDown:
            0.6
       case .indexPointingUp:
            0.6
       case .indexPointingAtTheViewer:
            14.0
       case .thumbsUp:
            0.6
       case .thumbsDown:
            0.6
       case .raisedFist:
            0.6
       case .oncomingFist:
            0.6
       case .leftFacingFist:
            3.0
       case .rightFacingFist:
            3.0
       case .clappingHands:
            0.6
       case .raisingHands:
            0.6
       case .heartHands:
            14.0
       case .openHands:
            0.6
       case .palmsUpTogether:
            5.0
       case .handshake:
            3.0
       case .foldedHands:
            0.6
       case .writingHand:
            0.7
       case .nailPolish:
            0.6
       case .selfie:
            3.0
       case .flexedBiceps:
            0.6
       case .mechanicalArm:
            12.0
       case .mechanicalLeg:
            12.0
       case .leg:
            11.0
       case .foot:
            11.0
       case .ear:
            0.6
       case .earWithHearingAid:
            12.0
       case .nose:
            0.6
       case .brain:
            5.0
       case .anatomicalHeart:
            13.0
       case .lungs:
            13.0
       case .tooth:
            11.0
       case .bone:
            11.0
       case .eyes:
            0.6
       case .eye:
            0.7
       case .tongue:
            0.6
       case .mouth:
            0.6
       case .bitingLip:
            14.0
       case .baby:
            0.6
       case .child:
            5.0
       case .boy:
            0.6
       case .girl:
            0.6
       case .person:
            5.0
       case .personBlondHair:
            0.6
       case .man:
            0.6
       case .personBeard:
            5.0
       case .manBeard:
            13.1
       case .womanBeard:
            13.1
       case .manRedHair:
            11.0
       case .manCurlyHair:
            11.0
       case .manWhiteHair:
            11.0
       case .manBald:
            11.0
       case .woman:
            0.6
       case .womanRedHair:
            11.0
       case .personRedHair:
            12.1
       case .womanCurlyHair:
            11.0
       case .personCurlyHair:
            12.1
       case .womanWhiteHair:
            11.0
       case .personWhiteHair:
            12.1
       case .womanBald:
            11.0
       case .personBald:
            12.1
       case .womanBlondHair:
            4.0
       case .manBlondHair:
            4.0
       case .olderPerson:
            5.0
       case .oldMan:
            0.6
       case .oldWoman:
            0.6
       case .personFrowning:
            0.6
       case .manFrowning:
            4.0
       case .womanFrowning:
            4.0
       case .personPouting:
            0.6
       case .manPouting:
            4.0
       case .womanPouting:
            4.0
       case .personGesturingNo:
            0.6
       case .manGesturingNo:
            4.0
       case .womanGesturingNo:
            4.0
       case .personGesturingOk:
            0.6
       case .manGesturingOk:
            4.0
       case .womanGesturingOk:
            4.0
       case .personTippingHand:
            0.6
       case .manTippingHand:
            4.0
       case .womanTippingHand:
            4.0
       case .personRaisingHand:
            0.6
       case .manRaisingHand:
            4.0
       case .womanRaisingHand:
            4.0
       case .deafPerson:
            12.0
       case .deafMan:
            12.0
       case .deafWoman:
            12.0
       case .personBowing:
            0.6
       case .manBowing:
            4.0
       case .womanBowing:
            4.0
       case .personFacepalming:
            3.0
       case .manFacepalming:
            4.0
       case .womanFacepalming:
            4.0
       case .personShrugging:
            3.0
       case .manShrugging:
            4.0
       case .womanShrugging:
            4.0
       case .healthWorker:
            12.1
       case .manHealthWorker:
            4.0
       case .womanHealthWorker:
            4.0
       case .student:
            12.1
       case .manStudent:
            4.0
       case .womanStudent:
            4.0
       case .teacher:
            12.1
       case .manTeacher:
            4.0
       case .womanTeacher:
            4.0
       case .judge:
            12.1
       case .manJudge:
            4.0
       case .womanJudge:
            4.0
       case .farmer:
            12.1
       case .manFarmer:
            4.0
       case .womanFarmer:
            4.0
       case .cook:
            12.1
       case .manCook:
            4.0
       case .womanCook:
            4.0
       case .mechanic:
            12.1
       case .manMechanic:
            4.0
       case .womanMechanic:
            4.0
       case .factoryWorker:
            12.1
       case .manFactoryWorker:
            4.0
       case .womanFactoryWorker:
            4.0
       case .officeWorker:
            12.1
       case .manOfficeWorker:
            4.0
       case .womanOfficeWorker:
            4.0
       case .scientist:
            12.1
       case .manScientist:
            4.0
       case .womanScientist:
            4.0
       case .technologist:
            12.1
       case .manTechnologist:
            4.0
       case .womanTechnologist:
            4.0
       case .singer:
            12.1
       case .manSinger:
            4.0
       case .womanSinger:
            4.0
       case .artist:
            12.1
       case .manArtist:
            4.0
       case .womanArtist:
            4.0
       case .pilot:
            12.1
       case .manPilot:
            4.0
       case .womanPilot:
            4.0
       case .astronaut:
            12.1
       case .manAstronaut:
            4.0
       case .womanAstronaut:
            4.0
       case .firefighter:
            12.1
       case .manFirefighter:
            4.0
       case .womanFirefighter:
            4.0
       case .policeOfficer:
            0.6
       case .manPoliceOfficer:
            4.0
       case .womanPoliceOfficer:
            4.0
       case .detective:
            0.7
       case .manDetective:
            4.0
       case .womanDetective:
            4.0
       case .personGuard:
            0.6
       case .manGuard:
            4.0
       case .womanGuard:
            4.0
       case .ninja:
            13.0
       case .constructionWorker:
            0.6
       case .manConstructionWorker:
            4.0
       case .womanConstructionWorker:
            4.0
       case .personWithCrown:
            14.0
       case .prince:
            3.0
       case .princess:
            0.6
       case .personWearingTurban:
            0.6
       case .manWearingTurban:
            4.0
       case .womanWearingTurban:
            4.0
       case .personWithSkullcap:
            0.6
       case .womanWithHeadscarf:
            5.0
       case .personInTuxedo:
            3.0
       case .manInTuxedo:
            13.0
       case .womanInTuxedo:
            13.0
       case .personWithVeil:
            0.6
       case .manWithVeil:
            13.0
       case .womanWithVeil:
            13.0
       case .pregnantWoman:
            3.0
       case .pregnantMan:
            14.0
       case .pregnantPerson:
            14.0
       case .breastFeeding:
            5.0
       case .womanFeedingBaby:
            13.0
       case .manFeedingBaby:
            13.0
       case .personFeedingBaby:
            13.0
       case .babyAngel:
            0.6
       case .santaClaus:
            0.6
       case .mrsClaus:
            3.0
       case .mxClaus:
            13.0
       case .superhero:
            11.0
       case .manSuperhero:
            11.0
       case .womanSuperhero:
            11.0
       case .supervillain:
            11.0
       case .manSupervillain:
            11.0
       case .womanSupervillain:
            11.0
       case .mage:
            5.0
       case .manMage:
            5.0
       case .womanMage:
            5.0
       case .fairy:
            5.0
       case .manFairy:
            5.0
       case .womanFairy:
            5.0
       case .vampire:
            5.0
       case .manVampire:
            5.0
       case .womanVampire:
            5.0
       case .merperson:
            5.0
       case .merman:
            5.0
       case .mermaid:
            5.0
       case .elf:
            5.0
       case .manElf:
            5.0
       case .womanElf:
            5.0
       case .genie:
            5.0
       case .manGenie:
            5.0
       case .womanGenie:
            5.0
       case .zombie:
            5.0
       case .manZombie:
            5.0
       case .womanZombie:
            5.0
       case .troll:
            14.0
       case .personGettingMassage:
            0.6
       case .manGettingMassage:
            4.0
       case .womanGettingMassage:
            4.0
       case .personGettingHaircut:
            0.6
       case .manGettingHaircut:
            4.0
       case .womanGettingHaircut:
            4.0
       case .personWalking:
            0.6
       case .manWalking:
            4.0
       case .womanWalking:
            4.0
       case .personWalkingFacingRight:
            15.1
       case .womanWalkingFacingRight:
            15.1
       case .manWalkingFacingRight:
            15.1
       case .personStanding:
            12.0
       case .manStanding:
            12.0
       case .womanStanding:
            12.0
       case .personKneeling:
            12.0
       case .manKneeling:
            12.0
       case .womanKneeling:
            12.0
       case .personKneelingFacingRight:
            15.1
       case .womanKneelingFacingRight:
            15.1
       case .manKneelingFacingRight:
            15.1
       case .personWithWhiteCane:
            12.1
       case .personWithWhiteCaneFacingRight:
            15.1
       case .manWithWhiteCane:
            12.0
       case .manWithWhiteCaneFacingRight:
            15.1
       case .womanWithWhiteCane:
            12.0
       case .womanWithWhiteCaneFacingRight:
            15.1
       case .personInMotorizedWheelchair:
            12.1
       case .personInMotorizedWheelchairFacingRight:
            15.1
       case .manInMotorizedWheelchair:
            12.0
       case .manInMotorizedWheelchairFacingRight:
            15.1
       case .womanInMotorizedWheelchair:
            12.0
       case .womanInMotorizedWheelchairFacingRight:
            15.1
       case .personInManualWheelchair:
            12.1
       case .personInManualWheelchairFacingRight:
            15.1
       case .manInManualWheelchair:
            12.0
       case .manInManualWheelchairFacingRight:
            15.1
       case .womanInManualWheelchair:
            12.0
       case .womanInManualWheelchairFacingRight:
            15.1
       case .personRunning:
            0.6
       case .manRunning:
            4.0
       case .womanRunning:
            4.0
       case .personRunningFacingRight:
            15.1
       case .womanRunningFacingRight:
            15.1
       case .manRunningFacingRight:
            15.1
       case .womanDancing:
            0.6
       case .manDancing:
            3.0
       case .personInSuitLevitating:
            0.7
       case .peopleWithBunnyEars:
            0.6
       case .menWithBunnyEars:
            4.0
       case .womenWithBunnyEars:
            4.0
       case .personInSteamyRoom:
            5.0
       case .manInSteamyRoom:
            5.0
       case .womanInSteamyRoom:
            5.0
       case .personClimbing:
            5.0
       case .manClimbing:
            5.0
       case .womanClimbing:
            5.0
       case .personFencing:
            3.0
       case .horseRacing:
            1.0
       case .skier:
            0.7
       case .snowboarder:
            0.6
       case .personGolfing:
            0.7
       case .manGolfing:
            4.0
       case .womanGolfing:
            4.0
       case .personSurfing:
            0.6
       case .manSurfing:
            4.0
       case .womanSurfing:
            4.0
       case .personRowingBoat:
            1.0
       case .manRowingBoat:
            4.0
       case .womanRowingBoat:
            4.0
       case .personSwimming:
            0.6
       case .manSwimming:
            4.0
       case .womanSwimming:
            4.0
       case .personBouncingBall:
            0.7
       case .manBouncingBall:
            4.0
       case .womanBouncingBall:
            4.0
       case .personLiftingWeights:
            0.7
       case .manLiftingWeights:
            4.0
       case .womanLiftingWeights:
            4.0
       case .personBiking:
            1.0
       case .manBiking:
            4.0
       case .womanBiking:
            4.0
       case .personMountainBiking:
            1.0
       case .manMountainBiking:
            4.0
       case .womanMountainBiking:
            4.0
       case .personCartwheeling:
            3.0
       case .manCartwheeling:
            4.0
       case .womanCartwheeling:
            4.0
       case .peopleWrestling:
            3.0
       case .menWrestling:
            4.0
       case .womenWrestling:
            4.0
       case .personPlayingWaterPolo:
            3.0
       case .manPlayingWaterPolo:
            4.0
       case .womanPlayingWaterPolo:
            4.0
       case .personPlayingHandball:
            3.0
       case .manPlayingHandball:
            4.0
       case .womanPlayingHandball:
            4.0
       case .personJuggling:
            3.0
       case .manJuggling:
            4.0
       case .womanJuggling:
            4.0
       case .personInLotusPosition:
            5.0
       case .manInLotusPosition:
            5.0
       case .womanInLotusPosition:
            5.0
       case .personTakingBath:
            0.6
       case .personInBed:
            1.0
       case .peopleHoldingHands:
            12.0
       case .womenHoldingHands:
            1.0
       case .womanAndManHoldingHands:
            0.6
       case .menHoldingHands:
            1.0
       case .kiss:
            0.6
       case .kissWomanMan:
            2.0
       case .kissManMan:
            2.0
       case .kissWomanWoman:
            2.0
       case .coupleWithHeart:
            0.6
       case .coupleWithHeartWomanMan:
            2.0
       case .coupleWithHeartManMan:
            2.0
       case .coupleWithHeartWomanWoman:
            2.0
       case .familyManWomanBoy:
            2.0
       case .familyManWomanGirl:
            2.0
       case .familyManWomanGirlBoy:
            2.0
       case .familyManWomanBoyBoy:
            2.0
       case .familyManWomanGirlGirl:
            2.0
       case .familyManManBoy:
            2.0
       case .familyManManGirl:
            2.0
       case .familyManManGirlBoy:
            2.0
       case .familyManManBoyBoy:
            2.0
       case .familyManManGirlGirl:
            2.0
       case .familyWomanWomanBoy:
            2.0
       case .familyWomanWomanGirl:
            2.0
       case .familyWomanWomanGirlBoy:
            2.0
       case .familyWomanWomanBoyBoy:
            2.0
       case .familyWomanWomanGirlGirl:
            2.0
       case .familyManBoy:
            4.0
       case .familyManBoyBoy:
            4.0
       case .familyManGirl:
            4.0
       case .familyManGirlBoy:
            4.0
       case .familyManGirlGirl:
            4.0
       case .familyWomanBoy:
            4.0
       case .familyWomanBoyBoy:
            4.0
       case .familyWomanGirl:
            4.0
       case .familyWomanGirlBoy:
            4.0
       case .familyWomanGirlGirl:
            4.0
       case .speakingHead:
            0.7
       case .bustInSilhouette:
            0.6
       case .bustsInSilhouette:
            1.0
       case .peopleHugging:
            13.0
       case .family:
            0.6
       case .familyAdultAdultChild:
            15.1
       case .familyAdultAdultChildChild:
            15.1
       case .familyAdultChild:
            15.1
       case .familyAdultChildChild:
            15.1
       case .footprints:
            0.6
       case .fingerprint:
            16.0
       case .monkeyFace:
            0.6
       case .monkey:
            0.6
       case .gorilla:
            3.0
       case .orangutan:
            12.0
       case .dogFace:
            0.6
       case .dog:
            0.7
       case .guideDog:
            12.0
       case .serviceDog:
            12.0
       case .poodle:
            0.6
       case .wolf:
            0.6
       case .fox:
            3.0
       case .raccoon:
            11.0
       case .catFace:
            0.6
       case .cat:
            0.7
       case .blackCat:
            13.0
       case .lion:
            1.0
       case .tigerFace:
            0.6
       case .tiger:
            1.0
       case .leopard:
            1.0
       case .horseFace:
            0.6
       case .moose:
            15.0
       case .donkey:
            15.0
       case .horse:
            0.6
       case .unicorn:
            1.0
       case .zebra:
            5.0
       case .deer:
            3.0
       case .bison:
            13.0
       case .cowFace:
            0.6
       case .ox:
            1.0
       case .waterBuffalo:
            1.0
       case .cow:
            1.0
       case .pigFace:
            0.6
       case .pig:
            1.0
       case .boar:
            0.6
       case .pigNose:
            0.6
       case .ram:
            1.0
       case .ewe:
            0.6
       case .goat:
            1.0
       case .camel:
            1.0
       case .twoHumpCamel:
            0.6
       case .llama:
            11.0
       case .giraffe:
            5.0
       case .elephant:
            0.6
       case .mammoth:
            13.0
       case .rhinoceros:
            3.0
       case .hippopotamus:
            11.0
       case .mouseFace:
            0.6
       case .mouse:
            1.0
       case .rat:
            1.0
       case .hamster:
            0.6
       case .rabbitFace:
            0.6
       case .rabbit:
            1.0
       case .chipmunk:
            0.7
       case .beaver:
            13.0
       case .hedgehog:
            5.0
       case .bat:
            3.0
       case .bear:
            0.6
       case .polarBear:
            13.0
       case .koala:
            0.6
       case .panda:
            0.6
       case .sloth:
            12.0
       case .otter:
            12.0
       case .skunk:
            12.0
       case .kangaroo:
            11.0
       case .badger:
            11.0
       case .pawPrints:
            0.6
       case .turkey:
            1.0
       case .chicken:
            0.6
       case .rooster:
            1.0
       case .hatchingChick:
            0.6
       case .babyChick:
            0.6
       case .frontFacingBabyChick:
            0.6
       case .bird:
            0.6
       case .penguin:
            0.6
       case .dove:
            0.7
       case .eagle:
            3.0
       case .duck:
            3.0
       case .swan:
            11.0
       case .owl:
            3.0
       case .dodo:
            13.0
       case .feather:
            13.0
       case .flamingo:
            12.0
       case .peacock:
            11.0
       case .parrot:
            11.0
       case .wing:
            15.0
       case .blackBird:
            15.0
       case .goose:
            15.0
       case .phoenix:
            15.1
       case .frog:
            0.6
       case .crocodile:
            1.0
       case .turtle:
            0.6
       case .lizard:
            3.0
       case .snake:
            0.6
       case .dragonFace:
            0.6
       case .dragon:
            1.0
       case .sauropod:
            5.0
       case .tRex:
            5.0
       case .spoutingWhale:
            0.6
       case .whale:
            1.0
       case .dolphin:
            0.6
       case .seal:
            13.0
       case .fish:
            0.6
       case .tropicalFish:
            0.6
       case .blowfish:
            0.6
       case .shark:
            3.0
       case .octopus:
            0.6
       case .spiralShell:
            0.6
       case .coral:
            14.0
       case .jellyfish:
            15.0
       case .crab:
            1.0
       case .lobster:
            11.0
       case .shrimp:
            3.0
       case .squid:
            3.0
       case .oyster:
            12.0
       case .snail:
            0.6
       case .butterfly:
            3.0
       case .bug:
            0.6
       case .ant:
            0.6
       case .honeybee:
            0.6
       case .beetle:
            13.0
       case .ladyBeetle:
            0.6
       case .cricket:
            5.0
       case .cockroach:
            13.0
       case .spider:
            0.7
       case .spiderWeb:
            0.7
       case .scorpion:
            1.0
       case .mosquito:
            11.0
       case .fly:
            13.0
       case .worm:
            13.0
       case .microbe:
            11.0
       case .bouquet:
            0.6
       case .cherryBlossom:
            0.6
       case .whiteFlower:
            0.6
       case .lotus:
            14.0
       case .rosette:
            0.7
       case .rose:
            0.6
       case .wiltedFlower:
            3.0
       case .hibiscus:
            0.6
       case .sunflower:
            0.6
       case .blossom:
            0.6
       case .tulip:
            0.6
       case .hyacinth:
            15.0
       case .seedling:
            0.6
       case .pottedPlant:
            13.0
       case .evergreenTree:
            1.0
       case .deciduousTree:
            1.0
       case .palmTree:
            0.6
       case .cactus:
            0.6
       case .sheafOfRice:
            0.6
       case .herb:
            0.6
       case .shamrock:
            1.0
       case .fourLeafClover:
            0.6
       case .mapleLeaf:
            0.6
       case .fallenLeaf:
            0.6
       case .leafFlutteringInWind:
            0.6
       case .emptyNest:
            14.0
       case .nestWithEggs:
            14.0
       case .mushroom:
            0.6
       case .leaflessTree:
            16.0
       case .grapes:
            0.6
       case .melon:
            0.6
       case .watermelon:
            0.6
       case .tangerine:
            0.6
       case .lemon:
            1.0
       case .lime:
            15.1
       case .banana:
            0.6
       case .pineapple:
            0.6
       case .mango:
            11.0
       case .redApple:
            0.6
       case .greenApple:
            0.6
       case .pear:
            1.0
       case .peach:
            0.6
       case .cherries:
            0.6
       case .strawberry:
            0.6
       case .blueberries:
            13.0
       case .kiwiFruit:
            3.0
       case .tomato:
            0.6
       case .olive:
            13.0
       case .coconut:
            5.0
       case .avocado:
            3.0
       case .eggplant:
            0.6
       case .potato:
            3.0
       case .carrot:
            3.0
       case .earOfCorn:
            0.6
       case .hotPepper:
            0.7
       case .bellPepper:
            13.0
       case .cucumber:
            3.0
       case .leafyGreen:
            11.0
       case .broccoli:
            5.0
       case .garlic:
            12.0
       case .onion:
            12.0
       case .peanuts:
            3.0
       case .beans:
            14.0
       case .chestnut:
            0.6
       case .gingerRoot:
            15.0
       case .peaPod:
            15.0
       case .brownMushroom:
            15.1
       case .rootVegetable:
            16.0
       case .bread:
            0.6
       case .croissant:
            3.0
       case .baguetteBread:
            3.0
       case .flatbread:
            13.0
       case .pretzel:
            5.0
       case .bagel:
            11.0
       case .pancakes:
            3.0
       case .waffle:
            12.0
       case .cheeseWedge:
            1.0
       case .meatOnBone:
            0.6
       case .poultryLeg:
            0.6
       case .cutOfMeat:
            5.0
       case .bacon:
            3.0
       case .hamburger:
            0.6
       case .frenchFries:
            0.6
       case .pizza:
            0.6
       case .hotDog:
            1.0
       case .sandwich:
            5.0
       case .taco:
            1.0
       case .burrito:
            1.0
       case .tamale:
            13.0
       case .stuffedFlatbread:
            3.0
       case .falafel:
            12.0
       case .egg:
            3.0
       case .cooking:
            0.6
       case .shallowPanOfFood:
            3.0
       case .potOfFood:
            0.6
       case .fondue:
            13.0
       case .bowlWithSpoon:
            5.0
       case .greenSalad:
            3.0
       case .popcorn:
            1.0
       case .butter:
            12.0
       case .salt:
            11.0
       case .cannedFood:
            5.0
       case .bentoBox:
            0.6
       case .riceCracker:
            0.6
       case .riceBall:
            0.6
       case .cookedRice:
            0.6
       case .curryRice:
            0.6
       case .steamingBowl:
            0.6
       case .spaghetti:
            0.6
       case .roastedSweetPotato:
            0.6
       case .oden:
            0.6
       case .sushi:
            0.6
       case .friedShrimp:
            0.6
       case .fishCakeWithSwirl:
            0.6
       case .moonCake:
            11.0
       case .dango:
            0.6
       case .dumpling:
            5.0
       case .fortuneCookie:
            5.0
       case .takeoutBox:
            5.0
       case .softIceCream:
            0.6
       case .shavedIce:
            0.6
       case .iceCream:
            0.6
       case .doughnut:
            0.6
       case .cookie:
            0.6
       case .birthdayCake:
            0.6
       case .shortcake:
            0.6
       case .cupcake:
            11.0
       case .pie:
            5.0
       case .chocolateBar:
            0.6
       case .candy:
            0.6
       case .lollipop:
            0.6
       case .custard:
            0.6
       case .honeyPot:
            0.6
       case .babyBottle:
            1.0
       case .glassOfMilk:
            3.0
       case .hotBeverage:
            0.6
       case .teapot:
            13.0
       case .teacupWithoutHandle:
            0.6
       case .sake:
            0.6
       case .bottleWithPoppingCork:
            1.0
       case .wineGlass:
            0.6
       case .cocktailGlass:
            0.6
       case .tropicalDrink:
            0.6
       case .beerMug:
            0.6
       case .clinkingBeerMugs:
            0.6
       case .clinkingGlasses:
            3.0
       case .tumblerGlass:
            3.0
       case .pouringLiquid:
            14.0
       case .cupWithStraw:
            5.0
       case .bubbleTea:
            13.0
       case .beverageBox:
            12.0
       case .mate:
            12.0
       case .ice:
            12.0
       case .chopsticks:
            5.0
       case .forkAndKnifeWithPlate:
            0.7
       case .forkAndKnife:
            0.6
       case .spoon:
            3.0
       case .kitchenKnife:
            0.6
       case .jar:
            14.0
       case .amphora:
            1.0
       case .globeShowingEuropeAfrica:
            0.7
       case .globeShowingAmericas:
            0.7
       case .globeShowingAsiaAustralia:
            0.6
       case .globeWithMeridians:
            1.0
       case .worldMap:
            0.7
       case .mapOfJapan:
            0.6
       case .compass:
            11.0
       case .snowCappedMountain:
            0.7
       case .mountain:
            0.7
       case .volcano:
            0.6
       case .mountFuji:
            0.6
       case .camping:
            0.7
       case .beachWithUmbrella:
            0.7
       case .desert:
            0.7
       case .desertIsland:
            0.7
       case .nationalPark:
            0.7
       case .stadium:
            0.7
       case .classicalBuilding:
            0.7
       case .buildingConstruction:
            0.7
       case .brick:
            11.0
       case .rock:
            13.0
       case .wood:
            13.0
       case .hut:
            13.0
       case .houses:
            0.7
       case .derelictHouse:
            0.7
       case .house:
            0.6
       case .houseWithGarden:
            0.6
       case .officeBuilding:
            0.6
       case .japanesePostOffice:
            0.6
       case .postOffice:
            1.0
       case .hospital:
            0.6
       case .bank:
            0.6
       case .hotel:
            0.6
       case .loveHotel:
            0.6
       case .convenienceStore:
            0.6
       case .school:
            0.6
       case .departmentStore:
            0.6
       case .factory:
            0.6
       case .japaneseCastle:
            0.6
       case .castle:
            0.6
       case .wedding:
            0.6
       case .tokyoTower:
            0.6
       case .statueOfLiberty:
            0.6
       case .church:
            0.6
       case .mosque:
            1.0
       case .hinduTemple:
            12.0
       case .synagogue:
            1.0
       case .shintoShrine:
            0.7
       case .kaaba:
            1.0
       case .fountain:
            0.6
       case .tent:
            0.6
       case .foggy:
            0.6
       case .nightWithStars:
            0.6
       case .cityscape:
            0.7
       case .sunriseOverMountains:
            0.6
       case .sunrise:
            0.6
       case .cityscapeAtDusk:
            0.6
       case .sunset:
            0.6
       case .bridgeAtNight:
            0.6
       case .hotSprings:
            0.6
       case .carouselHorse:
            0.6
       case .playgroundSlide:
            14.0
       case .ferrisWheel:
            0.6
       case .rollerCoaster:
            0.6
       case .barberPole:
            0.6
       case .circusTent:
            0.6
       case .locomotive:
            1.0
       case .railwayCar:
            0.6
       case .highSpeedTrain:
            0.6
       case .bulletTrain:
            0.6
       case .train:
            1.0
       case .metro:
            0.6
       case .lightRail:
            1.0
       case .station:
            0.6
       case .tram:
            1.0
       case .monorail:
            1.0
       case .mountainRailway:
            1.0
       case .tramCar:
            1.0
       case .bus:
            0.6
       case .oncomingBus:
            0.7
       case .trolleybus:
            1.0
       case .minibus:
            1.0
       case .ambulance:
            0.6
       case .fireEngine:
            0.6
       case .policeCar:
            0.6
       case .oncomingPoliceCar:
            0.7
       case .taxi:
            0.6
       case .oncomingTaxi:
            1.0
       case .automobile:
            0.6
       case .oncomingAutomobile:
            0.7
       case .sportUtilityVehicle:
            0.6
       case .pickupTruck:
            13.0
       case .deliveryTruck:
            0.6
       case .articulatedLorry:
            1.0
       case .tractor:
            1.0
       case .racingCar:
            0.7
       case .motorcycle:
            0.7
       case .motorScooter:
            3.0
       case .manualWheelchair:
            12.0
       case .motorizedWheelchair:
            12.0
       case .autoRickshaw:
            12.0
       case .bicycle:
            0.6
       case .kickScooter:
            3.0
       case .skateboard:
            11.0
       case .rollerSkate:
            13.0
       case .busStop:
            0.6
       case .motorway:
            0.7
       case .railwayTrack:
            0.7
       case .oilDrum:
            0.7
       case .fuelPump:
            0.6
       case .wheel:
            14.0
       case .policeCarLight:
            0.6
       case .horizontalTrafficLight:
            0.6
       case .verticalTrafficLight:
            1.0
       case .stopSign:
            3.0
       case .construction:
            0.6
       case .anchor:
            0.6
       case .ringBuoy:
            14.0
       case .sailboat:
            0.6
       case .canoe:
            3.0
       case .speedboat:
            0.6
       case .passengerShip:
            0.7
       case .ferry:
            0.7
       case .motorBoat:
            0.7
       case .ship:
            0.6
       case .airplane:
            0.6
       case .smallAirplane:
            0.7
       case .airplaneDeparture:
            1.0
       case .airplaneArrival:
            1.0
       case .parachute:
            12.0
       case .seat:
            0.6
       case .helicopter:
            1.0
       case .suspensionRailway:
            1.0
       case .mountainCableway:
            1.0
       case .aerialTramway:
            1.0
       case .satellite:
            0.7
       case .rocket:
            0.6
       case .flyingSaucer:
            5.0
       case .bellhopBell:
            0.7
       case .luggage:
            11.0
       case .hourglassDone:
            0.6
       case .hourglassNotDone:
            0.6
       case .watch:
            0.6
       case .alarmClock:
            0.6
       case .stopwatch:
            1.0
       case .timerClock:
            1.0
       case .mantelpieceClock:
            0.7
       case .twelveOClock:
            0.6
       case .twelveThirty:
            0.7
       case .oneOClock:
            0.6
       case .oneThirty:
            0.7
       case .twoOClock:
            0.6
       case .twoThirty:
            0.7
       case .threeOClock:
            0.6
       case .threeThirty:
            0.7
       case .fourOClock:
            0.6
       case .fourThirty:
            0.7
       case .fiveOClock:
            0.6
       case .fiveThirty:
            0.7
       case .sixOClock:
            0.6
       case .sixThirty:
            0.7
       case .sevenOClock:
            0.6
       case .sevenThirty:
            0.7
       case .eightOClock:
            0.6
       case .eightThirty:
            0.7
       case .nineOClock:
            0.6
       case .nineThirty:
            0.7
       case .tenOClock:
            0.6
       case .tenThirty:
            0.7
       case .elevenOClock:
            0.6
       case .elevenThirty:
            0.7
       case .newMoon:
            0.6
       case .waxingCrescentMoon:
            1.0
       case .firstQuarterMoon:
            0.6
       case .waxingGibbousMoon:
            0.6
       case .fullMoon:
            0.6
       case .waningGibbousMoon:
            1.0
       case .lastQuarterMoon:
            1.0
       case .waningCrescentMoon:
            1.0
       case .crescentMoon:
            0.6
       case .newMoonFace:
            1.0
       case .firstQuarterMoonFace:
            0.6
       case .lastQuarterMoonFace:
            0.7
       case .thermometer:
            0.7
       case .sun:
            0.6
       case .fullMoonFace:
            1.0
       case .sunWithFace:
            1.0
       case .ringedPlanet:
            12.0
       case .star:
            0.6
       case .glowingStar:
            0.6
       case .shootingStar:
            0.6
       case .milkyWay:
            0.6
       case .cloud:
            0.6
       case .sunBehindCloud:
            0.6
       case .cloudWithLightningAndRain:
            0.7
       case .sunBehindSmallCloud:
            0.7
       case .sunBehindLargeCloud:
            0.7
       case .sunBehindRainCloud:
            0.7
       case .cloudWithRain:
            0.7
       case .cloudWithSnow:
            0.7
       case .cloudWithLightning:
            0.7
       case .tornado:
            0.7
       case .fog:
            0.7
       case .windFace:
            0.7
       case .cyclone:
            0.6
       case .rainbow:
            0.6
       case .closedUmbrella:
            0.6
       case .umbrella:
            0.7
       case .umbrellaWithRainDrops:
            0.6
       case .umbrellaOnGround:
            0.7
       case .highVoltage:
            0.6
       case .snowflake:
            0.6
       case .snowman:
            0.7
       case .snowmanWithoutSnow:
            0.6
       case .comet:
            1.0
       case .fire:
            0.6
       case .droplet:
            0.6
       case .waterWave:
            0.6
       case .jackOLantern:
            0.6
       case .christmasTree:
            0.6
       case .fireworks:
            0.6
       case .sparkler:
            0.6
       case .firecracker:
            11.0
       case .sparkles:
            0.6
       case .balloon:
            0.6
       case .partyPopper:
            0.6
       case .confettiBall:
            0.6
       case .tanabataTree:
            0.6
       case .pineDecoration:
            0.6
       case .japaneseDolls:
            0.6
       case .carpStreamer:
            0.6
       case .windChime:
            0.6
       case .moonViewingCeremony:
            0.6
       case .redEnvelope:
            11.0
       case .ribbon:
            0.6
       case .wrappedGift:
            0.6
       case .reminderRibbon:
            0.7
       case .admissionTickets:
            0.7
       case .ticket:
            0.6
       case .militaryMedal:
            0.7
       case .trophy:
            0.6
       case .sportsMedal:
            1.0
       case .firstPlaceMedal:
            3.0
       case .secondPlaceMedal:
            3.0
       case .thirdPlaceMedal:
            3.0
       case .soccerBall:
            0.6
       case .baseball:
            0.6
       case .softball:
            11.0
       case .basketball:
            0.6
       case .volleyball:
            1.0
       case .americanFootball:
            0.6
       case .rugbyFootball:
            1.0
       case .tennis:
            0.6
       case .flyingDisc:
            11.0
       case .bowling:
            0.6
       case .cricketGame:
            1.0
       case .fieldHockey:
            1.0
       case .iceHockey:
            1.0
       case .lacrosse:
            11.0
       case .pingPong:
            1.0
       case .badminton:
            1.0
       case .boxingGlove:
            3.0
       case .martialArtsUniform:
            3.0
       case .goalNet:
            3.0
       case .flagInHole:
            0.6
       case .iceSkate:
            0.7
       case .fishingPole:
            0.6
       case .divingMask:
            12.0
       case .runningShirt:
            0.6
       case .skis:
            0.6
       case .sled:
            5.0
       case .curlingStone:
            5.0
       case .bullseye:
            0.6
       case .yoYo:
            12.0
       case .kite:
            12.0
       case .waterPistol:
            0.6
       case .pool8Ball:
            0.6
       case .crystalBall:
            0.6
       case .magicWand:
            13.0
       case .videoGame:
            0.6
       case .joystick:
            0.7
       case .slotMachine:
            0.6
       case .gameDie:
            0.6
       case .puzzlePiece:
            11.0
       case .teddyBear:
            11.0
       case .pinata:
            13.0
       case .mirrorBall:
            14.0
       case .nestingDolls:
            13.0
       case .spadeSuit:
            0.6
       case .heartSuit:
            0.6
       case .diamondSuit:
            0.6
       case .clubSuit:
            0.6
       case .chessPawn:
            11.0
       case .joker:
            0.6
       case .mahjongRedDragon:
            0.6
       case .flowerPlayingCards:
            0.6
       case .performingArts:
            0.6
       case .framedPicture:
            0.7
       case .artistPalette:
            0.6
       case .thread:
            11.0
       case .sewingNeedle:
            13.0
       case .yarn:
            11.0
       case .knot:
            13.0
       case .glasses:
            0.6
       case .sunglasses:
            0.7
       case .goggles:
            11.0
       case .labCoat:
            11.0
       case .safetyVest:
            12.0
       case .necktie:
            0.6
       case .tShirt:
            0.6
       case .jeans:
            0.6
       case .scarf:
            5.0
       case .gloves:
            5.0
       case .coat:
            5.0
       case .socks:
            5.0
       case .dress:
            0.6
       case .kimono:
            0.6
       case .sari:
            12.0
       case .onePieceSwimsuit:
            12.0
       case .briefs:
            12.0
       case .shorts:
            12.0
       case .bikini:
            0.6
       case .womanSClothes:
            0.6
       case .foldingHandFan:
            15.0
       case .purse:
            0.6
       case .handbag:
            0.6
       case .clutchBag:
            0.6
       case .shoppingBags:
            0.7
       case .backpack:
            0.6
       case .thongSandal:
            13.0
       case .manSShoe:
            0.6
       case .runningShoe:
            0.6
       case .hikingBoot:
            11.0
       case .flatShoe:
            11.0
       case .highHeeledShoe:
            0.6
       case .womanSSandal:
            0.6
       case .balletShoes:
            12.0
       case .womanSBoot:
            0.6
       case .hairPick:
            15.0
       case .crown:
            0.6
       case .womanSHat:
            0.6
       case .topHat:
            0.6
       case .graduationCap:
            0.6
       case .billedCap:
            5.0
       case .militaryHelmet:
            13.0
       case .rescueWorkerSHelmet:
            0.7
       case .prayerBeads:
            1.0
       case .lipstick:
            0.6
       case .ring:
            0.6
       case .gemStone:
            0.6
       case .mutedSpeaker:
            1.0
       case .speakerLowVolume:
            0.7
       case .speakerMediumVolume:
            1.0
       case .speakerHighVolume:
            0.6
       case .loudspeaker:
            0.6
       case .megaphone:
            0.6
       case .postalHorn:
            1.0
       case .bell:
            0.6
       case .bellWithSlash:
            1.0
       case .musicalScore:
            0.6
       case .musicalNote:
            0.6
       case .musicalNotes:
            0.6
       case .studioMicrophone:
            0.7
       case .levelSlider:
            0.7
       case .controlKnobs:
            0.7
       case .microphone:
            0.6
       case .headphone:
            0.6
       case .radio:
            0.6
       case .saxophone:
            0.6
       case .accordion:
            13.0
       case .guitar:
            0.6
       case .musicalKeyboard:
            0.6
       case .trumpet:
            0.6
       case .violin:
            0.6
       case .banjo:
            12.0
       case .drum:
            3.0
       case .longDrum:
            13.0
       case .maracas:
            15.0
       case .flute:
            15.0
       case .harp:
            16.0
       case .mobilePhone:
            0.6
       case .mobilePhoneWithArrow:
            0.6
       case .telephone:
            0.6
       case .telephoneReceiver:
            0.6
       case .pager:
            0.6
       case .faxMachine:
            0.6
       case .battery:
            0.6
       case .lowBattery:
            14.0
       case .electricPlug:
            0.6
       case .laptop:
            0.6
       case .desktopComputer:
            0.7
       case .printer:
            0.7
       case .keyboard:
            1.0
       case .computerMouse:
            0.7
       case .trackball:
            0.7
       case .computerDisk:
            0.6
       case .floppyDisk:
            0.6
       case .opticalDisk:
            0.6
       case .dvd:
            0.6
       case .abacus:
            11.0
       case .movieCamera:
            0.6
       case .filmFrames:
            0.7
       case .filmProjector:
            0.7
       case .clapperBoard:
            0.6
       case .television:
            0.6
       case .camera:
            0.6
       case .cameraWithFlash:
            1.0
       case .videoCamera:
            0.6
       case .videocassette:
            0.6
       case .magnifyingGlassTiltedLeft:
            0.6
       case .magnifyingGlassTiltedRight:
            0.6
       case .candle:
            0.7
       case .lightBulb:
            0.6
       case .flashlight:
            0.6
       case .redPaperLantern:
            0.6
       case .diyaLamp:
            12.0
       case .notebookWithDecorativeCover:
            0.6
       case .closedBook:
            0.6
       case .openBook:
            0.6
       case .greenBook:
            0.6
       case .blueBook:
            0.6
       case .orangeBook:
            0.6
       case .books:
            0.6
       case .notebook:
            0.6
       case .ledger:
            0.6
       case .pageWithCurl:
            0.6
       case .scroll:
            0.6
       case .pageFacingUp:
            0.6
       case .newspaper:
            0.6
       case .rolledUpNewspaper:
            0.7
       case .bookmarkTabs:
            0.6
       case .bookmark:
            0.6
       case .label:
            0.7
       case .moneyBag:
            0.6
       case .coin:
            13.0
       case .yenBanknote:
            0.6
       case .dollarBanknote:
            0.6
       case .euroBanknote:
            1.0
       case .poundBanknote:
            1.0
       case .moneyWithWings:
            0.6
       case .creditCard:
            0.6
       case .receipt:
            11.0
       case .chartIncreasingWithYen:
            0.6
       case .envelope:
            0.6
       case .eMail:
            0.6
       case .incomingEnvelope:
            0.6
       case .envelopeWithArrow:
            0.6
       case .outboxTray:
            0.6
       case .inboxTray:
            0.6
       case .package:
            0.6
       case .closedMailboxWithRaisedFlag:
            0.6
       case .closedMailboxWithLoweredFlag:
            0.6
       case .openMailboxWithRaisedFlag:
            0.7
       case .openMailboxWithLoweredFlag:
            0.7
       case .postbox:
            0.6
       case .ballotBoxWithBallot:
            0.7
       case .pencil:
            0.6
       case .blackNib:
            0.6
       case .fountainPen:
            0.7
       case .pen:
            0.7
       case .paintbrush:
            0.7
       case .crayon:
            0.7
       case .memo:
            0.6
       case .briefcase:
            0.6
       case .fileFolder:
            0.6
       case .openFileFolder:
            0.6
       case .cardIndexDividers:
            0.7
       case .calendar:
            0.6
       case .tearOffCalendar:
            0.6
       case .spiralNotepad:
            0.7
       case .spiralCalendar:
            0.7
       case .cardIndex:
            0.6
       case .chartIncreasing:
            0.6
       case .chartDecreasing:
            0.6
       case .barChart:
            0.6
       case .clipboard:
            0.6
       case .pushpin:
            0.6
       case .roundPushpin:
            0.6
       case .paperclip:
            0.6
       case .linkedPaperclips:
            0.7
       case .straightRuler:
            0.6
       case .triangularRuler:
            0.6
       case .scissors:
            0.6
       case .cardFileBox:
            0.7
       case .fileCabinet:
            0.7
       case .wastebasket:
            0.7
       case .locked:
            0.6
       case .unlocked:
            0.6
       case .lockedWithPen:
            0.6
       case .lockedWithKey:
            0.6
       case .key:
            0.6
       case .oldKey:
            0.7
       case .hammer:
            0.6
       case .axe:
            12.0
       case .pick:
            0.7
       case .hammerAndPick:
            1.0
       case .hammerAndWrench:
            0.7
       case .dagger:
            0.7
       case .crossedSwords:
            1.0
       case .bomb:
            0.6
       case .boomerang:
            13.0
       case .bowAndArrow:
            1.0
       case .shield:
            0.7
       case .carpentrySaw:
            13.0
       case .wrench:
            0.6
       case .screwdriver:
            13.0
       case .nutAndBolt:
            0.6
       case .gear:
            1.0
       case .clamp:
            0.7
       case .balanceScale:
            1.0
       case .whiteCane:
            12.0
       case .link:
            0.6
       case .brokenChain:
            15.1
       case .chains:
            0.7
       case .hook:
            13.0
       case .toolbox:
            11.0
       case .magnet:
            11.0
       case .ladder:
            13.0
       case .shovel:
            16.0
       case .alembic:
            1.0
       case .testTube:
            11.0
       case .petriDish:
            11.0
       case .dna:
            11.0
       case .microscope:
            1.0
       case .telescope:
            1.0
       case .satelliteAntenna:
            0.6
       case .syringe:
            0.6
       case .dropOfBlood:
            12.0
       case .pill:
            0.6
       case .adhesiveBandage:
            12.0
       case .crutch:
            14.0
       case .stethoscope:
            12.0
       case .xRay:
            14.0
       case .door:
            0.6
       case .elevator:
            13.0
       case .mirror:
            13.0
       case .window:
            13.0
       case .bed:
            0.7
       case .couchAndLamp:
            0.7
       case .chair:
            12.0
       case .toilet:
            0.6
       case .plunger:
            13.0
       case .shower:
            1.0
       case .bathtub:
            1.0
       case .mouseTrap:
            13.0
       case .razor:
            12.0
       case .lotionBottle:
            11.0
       case .safetyPin:
            11.0
       case .broom:
            11.0
       case .basket:
            11.0
       case .rollOfPaper:
            11.0
       case .bucket:
            13.0
       case .soap:
            11.0
       case .bubbles:
            14.0
       case .toothbrush:
            13.0
       case .sponge:
            11.0
       case .fireExtinguisher:
            11.0
       case .shoppingCart:
            3.0
       case .cigarette:
            0.6
       case .coffin:
            1.0
       case .headstone:
            13.0
       case .funeralUrn:
            1.0
       case .nazarAmulet:
            11.0
       case .hamsa:
            14.0
       case .moai:
            0.6
       case .placard:
            13.0
       case .identificationCard:
            14.0
       case .atmSign:
            0.6
       case .litterInBinSign:
            1.0
       case .potableWater:
            1.0
       case .wheelchairSymbol:
            0.6
       case .menSRoom:
            0.6
       case .womenSRoom:
            0.6
       case .restroom:
            0.6
       case .babySymbol:
            0.6
       case .waterCloset:
            0.6
       case .passportControl:
            1.0
       case .customs:
            1.0
       case .baggageClaim:
            1.0
       case .leftLuggage:
            1.0
       case .warning:
            0.6
       case .childrenCrossing:
            1.0
       case .noEntry:
            0.6
       case .prohibited:
            0.6
       case .noBicycles:
            1.0
       case .noSmoking:
            0.6
       case .noLittering:
            1.0
       case .nonPotableWater:
            1.0
       case .noPedestrians:
            1.0
       case .noMobilePhones:
            1.0
       case .noOneUnderEighteen:
            0.6
       case .radioactive:
            1.0
       case .biohazard:
            1.0
       case .upArrow:
            0.6
       case .upRightArrow:
            0.6
       case .rightArrow:
            0.6
       case .downRightArrow:
            0.6
       case .downArrow:
            0.6
       case .downLeftArrow:
            0.6
       case .leftArrow:
            0.6
       case .upLeftArrow:
            0.6
       case .upDownArrow:
            0.6
       case .leftRightArrow:
            0.6
       case .rightArrowCurvingLeft:
            0.6
       case .leftArrowCurvingRight:
            0.6
       case .rightArrowCurvingUp:
            0.6
       case .rightArrowCurvingDown:
            0.6
       case .clockwiseVerticalArrows:
            0.6
       case .counterclockwiseArrowsButton:
            1.0
       case .backArrow:
            0.6
       case .endArrow:
            0.6
       case .onArrow:
            0.6
       case .soonArrow:
            0.6
       case .topArrow:
            0.6
       case .placeOfWorship:
            1.0
       case .atomSymbol:
            1.0
       case .om:
            0.7
       case .starOfDavid:
            0.7
       case .wheelOfDharma:
            0.7
       case .yinYang:
            0.7
       case .latinCross:
            0.7
       case .orthodoxCross:
            1.0
       case .starAndCrescent:
            0.7
       case .peaceSymbol:
            1.0
       case .menorah:
            1.0
       case .dottedSixPointedStar:
            0.6
       case .khanda:
            15.0
       case .aries:
            0.6
       case .taurus:
            0.6
       case .gemini:
            0.6
       case .cancer:
            0.6
       case .leo:
            0.6
       case .virgo:
            0.6
       case .libra:
            0.6
       case .scorpio:
            0.6
       case .sagittarius:
            0.6
       case .capricorn:
            0.6
       case .aquarius:
            0.6
       case .pisces:
            0.6
       case .ophiuchus:
            0.6
       case .shuffleTracksButton:
            1.0
       case .repeatButton:
            1.0
       case .repeatSingleButton:
            1.0
       case .playButton:
            0.6
       case .fastForwardButton:
            0.6
       case .nextTrackButton:
            0.7
       case .playOrPauseButton:
            1.0
       case .reverseButton:
            0.6
       case .fastReverseButton:
            0.6
       case .lastTrackButton:
            0.7
       case .upwardsButton:
            0.6
       case .fastUpButton:
            0.6
       case .downwardsButton:
            0.6
       case .fastDownButton:
            0.6
       case .pauseButton:
            0.7
       case .stopButton:
            0.7
       case .recordButton:
            0.7
       case .ejectButton:
            1.0
       case .cinema:
            0.6
       case .dimButton:
            1.0
       case .brightButton:
            1.0
       case .antennaBars:
            0.6
       case .wireless:
            15.0
       case .vibrationMode:
            0.6
       case .mobilePhoneOff:
            0.6
       case .femaleSign:
            4.0
       case .maleSign:
            4.0
       case .transgenderSymbol:
            13.0
       case .multiply:
            0.6
       case .plus:
            0.6
       case .minus:
            0.6
       case .divide:
            0.6
       case .heavyEqualsSign:
            14.0
       case .infinity:
            11.0
       case .doubleExclamationMark:
            0.6
       case .exclamationQuestionMark:
            0.6
       case .redQuestionMark:
            0.6
       case .whiteQuestionMark:
            0.6
       case .whiteExclamationMark:
            0.6
       case .redExclamationMark:
            0.6
       case .wavyDash:
            0.6
       case .currencyExchange:
            0.6
       case .heavyDollarSign:
            0.6
       case .medicalSymbol:
            4.0
       case .recyclingSymbol:
            0.6
       case .fleurDeLis:
            1.0
       case .tridentEmblem:
            0.6
       case .nameBadge:
            0.6
       case .japaneseSymbolForBeginner:
            0.6
       case .hollowRedCircle:
            0.6
       case .checkMarkButton:
            0.6
       case .checkBoxWithCheck:
            0.6
       case .checkMark:
            0.6
       case .crossMark:
            0.6
       case .crossMarkButton:
            0.6
       case .curlyLoop:
            0.6
       case .doubleCurlyLoop:
            1.0
       case .partAlternationMark:
            0.6
       case .eightSpokedAsterisk:
            0.6
       case .eightPointedStar:
            0.6
       case .sparkle:
            0.6
       case .copyright:
            0.6
       case .registered:
            0.6
       case .tradeMark:
            0.6
       case .splatter:
            16.0
       case .keycapRoute:
            0.6
       case .keycapStar:
            2.0
       case .keycap0:
            0.6
       case .keycap1:
            0.6
       case .keycap2:
            0.6
       case .keycap3:
            0.6
       case .keycap4:
            0.6
       case .keycap5:
            0.6
       case .keycap6:
            0.6
       case .keycap7:
            0.6
       case .keycap8:
            0.6
       case .keycap9:
            0.6
       case .keycap10:
            0.6
       case .inputLatinUppercase:
            0.6
       case .inputLatinLowercase:
            0.6
       case .inputNumbers:
            0.6
       case .inputSymbols:
            0.6
       case .inputLatinLetters:
            0.6
       case .aButtonBloodType:
            0.6
       case .abButtonBloodType:
            0.6
       case .bButtonBloodType:
            0.6
       case .clButton:
            0.6
       case .coolButton:
            0.6
       case .freeButton:
            0.6
       case .information:
            0.6
       case .idButton:
            0.6
       case .circledM:
            0.6
       case .newButton:
            0.6
       case .ngButton:
            0.6
       case .oButtonBloodType:
            0.6
       case .okButton:
            0.6
       case .pButton:
            0.6
       case .sosButton:
            0.6
       case .upButton:
            0.6
       case .vsButton:
            0.6
       case .japaneseHereButton:
            0.6
       case .japaneseServiceChargeButton:
            0.6
       case .japaneseMonthlyAmountButton:
            0.6
       case .japaneseNotFreeOfChargeButton:
            0.6
       case .japaneseReservedButton:
            0.6
       case .japaneseBargainButton:
            0.6
       case .japaneseDiscountButton:
            0.6
       case .japaneseFreeOfChargeButton:
            0.6
       case .japaneseProhibitedButton:
            0.6
       case .japaneseAcceptableButton:
            0.6
       case .japaneseApplicationButton:
            0.6
       case .japanesePassingGradeButton:
            0.6
       case .japaneseVacancyButton:
            0.6
       case .japaneseCongratulationsButton:
            0.6
       case .japaneseSecretButton:
            0.6
       case .japaneseOpenForBusinessButton:
            0.6
       case .japaneseNoVacancyButton:
            0.6
       case .redCircle:
            0.6
       case .orangeCircle:
            12.0
       case .yellowCircle:
            12.0
       case .greenCircle:
            12.0
       case .blueCircle:
            0.6
       case .purpleCircle:
            12.0
       case .brownCircle:
            12.0
       case .blackCircle:
            0.6
       case .whiteCircle:
            0.6
       case .redSquare:
            12.0
       case .orangeSquare:
            12.0
       case .yellowSquare:
            12.0
       case .greenSquare:
            12.0
       case .blueSquare:
            12.0
       case .purpleSquare:
            12.0
       case .brownSquare:
            12.0
       case .blackLargeSquare:
            0.6
       case .whiteLargeSquare:
            0.6
       case .blackMediumSquare:
            0.6
       case .whiteMediumSquare:
            0.6
       case .blackMediumSmallSquare:
            0.6
       case .whiteMediumSmallSquare:
            0.6
       case .blackSmallSquare:
            0.6
       case .whiteSmallSquare:
            0.6
       case .largeOrangeDiamond:
            0.6
       case .largeBlueDiamond:
            0.6
       case .smallOrangeDiamond:
            0.6
       case .smallBlueDiamond:
            0.6
       case .redTrianglePointedUp:
            0.6
       case .redTrianglePointedDown:
            0.6
       case .diamondWithADot:
            0.6
       case .radioButton:
            0.6
       case .whiteSquareButton:
            0.6
       case .blackSquareButton:
            0.6
       case .chequeredFlag:
            0.6
       case .triangularFlag:
            0.6
       case .crossedFlags:
            0.6
       case .blackFlag:
            1.0
       case .whiteFlag:
            0.7
       case .rainbowFlag:
            4.0
       case .transgenderFlag:
            13.0
       case .pirateFlag:
            11.0
       case .flagAscensionIsland:
            2.0
       case .flagAndorra:
            2.0
       case .flagUnitedArabEmirates:
            2.0
       case .flagAfghanistan:
            2.0
       case .flagAntiguaBarbuda:
            2.0
       case .flagAnguilla:
            2.0
       case .flagAlbania:
            2.0
       case .flagArmenia:
            2.0
       case .flagAngola:
            2.0
       case .flagAntarctica:
            2.0
       case .flagArgentina:
            2.0
       case .flagAmericanSamoa:
            2.0
       case .flagAustria:
            2.0
       case .flagAustralia:
            2.0
       case .flagAruba:
            2.0
       case .flagAlandIslands:
            2.0
       case .flagAzerbaijan:
            2.0
       case .flagBosniaHerzegovina:
            2.0
       case .flagBarbados:
            2.0
       case .flagBangladesh:
            2.0
       case .flagBelgium:
            2.0
       case .flagBurkinaFaso:
            2.0
       case .flagBulgaria:
            2.0
       case .flagBahrain:
            2.0
       case .flagBurundi:
            2.0
       case .flagBenin:
            2.0
       case .flagStBarthelemy:
            2.0
       case .flagBermuda:
            2.0
       case .flagBrunei:
            2.0
       case .flagBolivia:
            2.0
       case .flagCaribbeanNetherlands:
            2.0
       case .flagBrazil:
            2.0
       case .flagBahamas:
            2.0
       case .flagBhutan:
            2.0
       case .flagBouvetIsland:
            2.0
       case .flagBotswana:
            2.0
       case .flagBelarus:
            2.0
       case .flagBelize:
            2.0
       case .flagCanada:
            2.0
       case .flagCocosKeelingIslands:
            2.0
       case .flagCongoKinshasa:
            2.0
       case .flagCentralAfricanRepublic:
            2.0
       case .flagCongoBrazzaville:
            2.0
       case .flagSwitzerland:
            2.0
       case .flagCoteDIvoire:
            2.0
       case .flagCookIslands:
            2.0
       case .flagChile:
            2.0
       case .flagCameroon:
            2.0
       case .flagChina:
            0.6
       case .flagColombia:
            2.0
       case .flagClippertonIsland:
            2.0
       case .flagSark:
            16.0
       case .flagCostaRica:
            2.0
       case .flagCuba:
            2.0
       case .flagCapeVerde:
            2.0
       case .flagCuracao:
            2.0
       case .flagChristmasIsland:
            2.0
       case .flagCyprus:
            2.0
       case .flagCzechia:
            2.0
       case .flagGermany:
            0.6
       case .flagDiegoGarcia:
            2.0
       case .flagDjibouti:
            2.0
       case .flagDenmark:
            2.0
       case .flagDominica:
            2.0
       case .flagDominicanRepublic:
            2.0
       case .flagAlgeria:
            2.0
       case .flagCeutaMelilla:
            2.0
       case .flagEcuador:
            2.0
       case .flagEstonia:
            2.0
       case .flagEgypt:
            2.0
       case .flagWesternSahara:
            2.0
       case .flagEritrea:
            2.0
       case .flagSpain:
            0.6
       case .flagEthiopia:
            2.0
       case .flagEuropeanUnion:
            2.0
       case .flagFinland:
            2.0
       case .flagFiji:
            2.0
       case .flagFalklandIslands:
            2.0
       case .flagMicronesia:
            2.0
       case .flagFaroeIslands:
            2.0
       case .flagFrance:
            0.6
       case .flagGabon:
            2.0
       case .flagUnitedKingdom:
            0.6
       case .flagGrenada:
            2.0
       case .flagGeorgia:
            2.0
       case .flagFrenchGuiana:
            2.0
       case .flagGuernsey:
            2.0
       case .flagGhana:
            2.0
       case .flagGibraltar:
            2.0
       case .flagGreenland:
            2.0
       case .flagGambia:
            2.0
       case .flagGuinea:
            2.0
       case .flagGuadeloupe:
            2.0
       case .flagEquatorialGuinea:
            2.0
       case .flagGreece:
            2.0
       case .flagSouthGeorgiaSouthSandwichIslands:
            2.0
       case .flagGuatemala:
            2.0
       case .flagGuam:
            2.0
       case .flagGuineaBissau:
            2.0
       case .flagGuyana:
            2.0
       case .flagHongKongSarChina:
            2.0
       case .flagHeardMcdonaldIslands:
            2.0
       case .flagHonduras:
            2.0
       case .flagCroatia:
            2.0
       case .flagHaiti:
            2.0
       case .flagHungary:
            2.0
       case .flagCanaryIslands:
            2.0
       case .flagIndonesia:
            2.0
       case .flagIreland:
            2.0
       case .flagIsrael:
            2.0
       case .flagIsleOfMan:
            2.0
       case .flagIndia:
            2.0
       case .flagBritishIndianOceanTerritory:
            2.0
       case .flagIraq:
            2.0
       case .flagIran:
            2.0
       case .flagIceland:
            2.0
       case .flagItaly:
            0.6
       case .flagJersey:
            2.0
       case .flagJamaica:
            2.0
       case .flagJordan:
            2.0
       case .flagJapan:
            0.6
       case .flagKenya:
            2.0
       case .flagKyrgyzstan:
            2.0
       case .flagCambodia:
            2.0
       case .flagKiribati:
            2.0
       case .flagComoros:
            2.0
       case .flagStKittsNevis:
            2.0
       case .flagNorthKorea:
            2.0
       case .flagSouthKorea:
            0.6
       case .flagKuwait:
            2.0
       case .flagCaymanIslands:
            2.0
       case .flagKazakhstan:
            2.0
       case .flagLaos:
            2.0
       case .flagLebanon:
            2.0
       case .flagStLucia:
            2.0
       case .flagLiechtenstein:
            2.0
       case .flagSriLanka:
            2.0
       case .flagLiberia:
            2.0
       case .flagLesotho:
            2.0
       case .flagLithuania:
            2.0
       case .flagLuxembourg:
            2.0
       case .flagLatvia:
            2.0
       case .flagLibya:
            2.0
       case .flagMorocco:
            2.0
       case .flagMonaco:
            2.0
       case .flagMoldova:
            2.0
       case .flagMontenegro:
            2.0
       case .flagStMartin:
            2.0
       case .flagMadagascar:
            2.0
       case .flagMarshallIslands:
            2.0
       case .flagNorthMacedonia:
            2.0
       case .flagMali:
            2.0
       case .flagMyanmarBurma:
            2.0
       case .flagMongolia:
            2.0
       case .flagMacaoSarChina:
            2.0
       case .flagNorthernMarianaIslands:
            2.0
       case .flagMartinique:
            2.0
       case .flagMauritania:
            2.0
       case .flagMontserrat:
            2.0
       case .flagMalta:
            2.0
       case .flagMauritius:
            2.0
       case .flagMaldives:
            2.0
       case .flagMalawi:
            2.0
       case .flagMexico:
            2.0
       case .flagMalaysia:
            2.0
       case .flagMozambique:
            2.0
       case .flagNamibia:
            2.0
       case .flagNewCaledonia:
            2.0
       case .flagNiger:
            2.0
       case .flagNorfolkIsland:
            2.0
       case .flagNigeria:
            2.0
       case .flagNicaragua:
            2.0
       case .flagNetherlands:
            2.0
       case .flagNorway:
            2.0
       case .flagNepal:
            2.0
       case .flagNauru:
            2.0
       case .flagNiue:
            2.0
       case .flagNewZealand:
            2.0
       case .flagOman:
            2.0
       case .flagPanama:
            2.0
       case .flagPeru:
            2.0
       case .flagFrenchPolynesia:
            2.0
       case .flagPapuaNewGuinea:
            2.0
       case .flagPhilippines:
            2.0
       case .flagPakistan:
            2.0
       case .flagPoland:
            2.0
       case .flagStPierreMiquelon:
            2.0
       case .flagPitcairnIslands:
            2.0
       case .flagPuertoRico:
            2.0
       case .flagPalestinianTerritories:
            2.0
       case .flagPortugal:
            2.0
       case .flagPalau:
            2.0
       case .flagParaguay:
            2.0
       case .flagQatar:
            2.0
       case .flagReunion:
            2.0
       case .flagRomania:
            2.0
       case .flagSerbia:
            2.0
       case .flagRussia:
            0.6
       case .flagRwanda:
            2.0
       case .flagSaudiArabia:
            2.0
       case .flagSolomonIslands:
            2.0
       case .flagSeychelles:
            2.0
       case .flagSudan:
            2.0
       case .flagSweden:
            2.0
       case .flagSingapore:
            2.0
       case .flagStHelena:
            2.0
       case .flagSlovenia:
            2.0
       case .flagSvalbardJanMayen:
            2.0
       case .flagSlovakia:
            2.0
       case .flagSierraLeone:
            2.0
       case .flagSanMarino:
            2.0
       case .flagSenegal:
            2.0
       case .flagSomalia:
            2.0
       case .flagSuriname:
            2.0
       case .flagSouthSudan:
            2.0
       case .flagSaoTomePrincipe:
            2.0
       case .flagElSalvador:
            2.0
       case .flagSintMaarten:
            2.0
       case .flagSyria:
            2.0
       case .flagEswatini:
            2.0
       case .flagTristanDaCunha:
            2.0
       case .flagTurksCaicosIslands:
            2.0
       case .flagChad:
            2.0
       case .flagFrenchSouthernTerritories:
            2.0
       case .flagTogo:
            2.0
       case .flagThailand:
            2.0
       case .flagTajikistan:
            2.0
       case .flagTokelau:
            2.0
       case .flagTimorLeste:
            2.0
       case .flagTurkmenistan:
            2.0
       case .flagTunisia:
            2.0
       case .flagTonga:
            2.0
       case .flagTurkiye:
            2.0
       case .flagTrinidadTobago:
            2.0
       case .flagTuvalu:
            2.0
       case .flagTaiwan:
            2.0
       case .flagTanzania:
            2.0
       case .flagUkraine:
            2.0
       case .flagUganda:
            2.0
       case .flagUSOutlyingIslands:
            2.0
       case .flagUnitedNations:
            4.0
       case .flagUnitedStates:
            0.6
       case .flagUruguay:
            2.0
       case .flagUzbekistan:
            2.0
       case .flagVaticanCity:
            2.0
       case .flagStVincentGrenadines:
            2.0
       case .flagVenezuela:
            2.0
       case .flagBritishVirginIslands:
            2.0
       case .flagUSVirginIslands:
            2.0
       case .flagVietnam:
            2.0
       case .flagVanuatu:
            2.0
       case .flagWallisFutuna:
            2.0
       case .flagSamoa:
            2.0
       case .flagKosovo:
            2.0
       case .flagYemen:
            2.0
       case .flagMayotte:
            2.0
       case .flagSouthAfrica:
            2.0
       case .flagZambia:
            2.0
       case .flagZimbabwe:
            2.0
       case .flagEngland:
            5.0
       case .flagScotland:
            5.0
       case .flagWales:
            5.0
        }
    }

}

public enum EmojiCategory {
    case activities
    case animalsNature
    case flags
    case foodDrink
    case objects
    case peopleBody
    case smileysEmotion
    case symbols
    case travelPlaces

    var emojis: [Emoji] {
      switch self {
      case .activities:
            return [ .jackOLantern, .christmasTree, .fireworks, .sparkler, .firecracker, .sparkles, .balloon, .partyPopper, .confettiBall, .tanabataTree, .pineDecoration, .japaneseDolls, .carpStreamer, .windChime, .moonViewingCeremony, .redEnvelope, .ribbon, .wrappedGift, .reminderRibbon, .admissionTickets, .ticket, .militaryMedal, .trophy, .sportsMedal, .firstPlaceMedal, .secondPlaceMedal, .thirdPlaceMedal, .soccerBall, .baseball, .softball, .basketball, .volleyball, .americanFootball, .rugbyFootball, .tennis, .flyingDisc, .bowling, .cricketGame, .fieldHockey, .iceHockey, .lacrosse, .pingPong, .badminton, .boxingGlove, .martialArtsUniform, .goalNet, .flagInHole, .iceSkate, .fishingPole, .divingMask, .runningShirt, .skis, .sled, .curlingStone, .bullseye, .yoYo, .kite, .waterPistol, .pool8Ball, .crystalBall, .magicWand, .videoGame, .joystick, .slotMachine, .gameDie, .puzzlePiece, .teddyBear, .pinata, .mirrorBall, .nestingDolls, .spadeSuit, .heartSuit, .diamondSuit, .clubSuit, .chessPawn, .joker, .mahjongRedDragon, .flowerPlayingCards, .performingArts, .framedPicture, .artistPalette, .thread, .sewingNeedle, .yarn, .knot]
      case .animalsNature:
            return [ .monkeyFace, .monkey, .gorilla, .orangutan, .dogFace, .dog, .guideDog, .serviceDog, .poodle, .wolf, .fox, .raccoon, .catFace, .cat, .blackCat, .lion, .tigerFace, .tiger, .leopard, .horseFace, .moose, .donkey, .horse, .unicorn, .zebra, .deer, .bison, .cowFace, .ox, .waterBuffalo, .cow, .pigFace, .pig, .boar, .pigNose, .ram, .ewe, .goat, .camel, .twoHumpCamel, .llama, .giraffe, .elephant, .mammoth, .rhinoceros, .hippopotamus, .mouseFace, .mouse, .rat, .hamster, .rabbitFace, .rabbit, .chipmunk, .beaver, .hedgehog, .bat, .bear, .polarBear, .koala, .panda, .sloth, .otter, .skunk, .kangaroo, .badger, .pawPrints, .turkey, .chicken, .rooster, .hatchingChick, .babyChick, .frontFacingBabyChick, .bird, .penguin, .dove, .eagle, .duck, .swan, .owl, .dodo, .feather, .flamingo, .peacock, .parrot, .wing, .blackBird, .goose, .phoenix, .frog, .crocodile, .turtle, .lizard, .snake, .dragonFace, .dragon, .sauropod, .tRex, .spoutingWhale, .whale, .dolphin, .seal, .fish, .tropicalFish, .blowfish, .shark, .octopus, .spiralShell, .coral, .jellyfish, .crab, .lobster, .shrimp, .squid, .oyster, .snail, .butterfly, .bug, .ant, .honeybee, .beetle, .ladyBeetle, .cricket, .cockroach, .spider, .spiderWeb, .scorpion, .mosquito, .fly, .worm, .microbe, .bouquet, .cherryBlossom, .whiteFlower, .lotus, .rosette, .rose, .wiltedFlower, .hibiscus, .sunflower, .blossom, .tulip, .hyacinth, .seedling, .pottedPlant, .evergreenTree, .deciduousTree, .palmTree, .cactus, .sheafOfRice, .herb, .shamrock, .fourLeafClover, .mapleLeaf, .fallenLeaf, .leafFlutteringInWind, .emptyNest, .nestWithEggs, .mushroom, .leaflessTree]
      case .flags:
            return [ .chequeredFlag, .triangularFlag, .crossedFlags, .blackFlag, .whiteFlag, .rainbowFlag, .transgenderFlag, .pirateFlag, .flagAscensionIsland, .flagAndorra, .flagUnitedArabEmirates, .flagAfghanistan, .flagAntiguaBarbuda, .flagAnguilla, .flagAlbania, .flagArmenia, .flagAngola, .flagAntarctica, .flagArgentina, .flagAmericanSamoa, .flagAustria, .flagAustralia, .flagAruba, .flagAlandIslands, .flagAzerbaijan, .flagBosniaHerzegovina, .flagBarbados, .flagBangladesh, .flagBelgium, .flagBurkinaFaso, .flagBulgaria, .flagBahrain, .flagBurundi, .flagBenin, .flagStBarthelemy, .flagBermuda, .flagBrunei, .flagBolivia, .flagCaribbeanNetherlands, .flagBrazil, .flagBahamas, .flagBhutan, .flagBouvetIsland, .flagBotswana, .flagBelarus, .flagBelize, .flagCanada, .flagCocosKeelingIslands, .flagCongoKinshasa, .flagCentralAfricanRepublic, .flagCongoBrazzaville, .flagSwitzerland, .flagCoteDIvoire, .flagCookIslands, .flagChile, .flagCameroon, .flagChina, .flagColombia, .flagClippertonIsland, .flagSark, .flagCostaRica, .flagCuba, .flagCapeVerde, .flagCuracao, .flagChristmasIsland, .flagCyprus, .flagCzechia, .flagGermany, .flagDiegoGarcia, .flagDjibouti, .flagDenmark, .flagDominica, .flagDominicanRepublic, .flagAlgeria, .flagCeutaMelilla, .flagEcuador, .flagEstonia, .flagEgypt, .flagWesternSahara, .flagEritrea, .flagSpain, .flagEthiopia, .flagEuropeanUnion, .flagFinland, .flagFiji, .flagFalklandIslands, .flagMicronesia, .flagFaroeIslands, .flagFrance, .flagGabon, .flagUnitedKingdom, .flagGrenada, .flagGeorgia, .flagFrenchGuiana, .flagGuernsey, .flagGhana, .flagGibraltar, .flagGreenland, .flagGambia, .flagGuinea, .flagGuadeloupe, .flagEquatorialGuinea, .flagGreece, .flagSouthGeorgiaSouthSandwichIslands, .flagGuatemala, .flagGuam, .flagGuineaBissau, .flagGuyana, .flagHongKongSarChina, .flagHeardMcdonaldIslands, .flagHonduras, .flagCroatia, .flagHaiti, .flagHungary, .flagCanaryIslands, .flagIndonesia, .flagIreland, .flagIsrael, .flagIsleOfMan, .flagIndia, .flagBritishIndianOceanTerritory, .flagIraq, .flagIran, .flagIceland, .flagItaly, .flagJersey, .flagJamaica, .flagJordan, .flagJapan, .flagKenya, .flagKyrgyzstan, .flagCambodia, .flagKiribati, .flagComoros, .flagStKittsNevis, .flagNorthKorea, .flagSouthKorea, .flagKuwait, .flagCaymanIslands, .flagKazakhstan, .flagLaos, .flagLebanon, .flagStLucia, .flagLiechtenstein, .flagSriLanka, .flagLiberia, .flagLesotho, .flagLithuania, .flagLuxembourg, .flagLatvia, .flagLibya, .flagMorocco, .flagMonaco, .flagMoldova, .flagMontenegro, .flagStMartin, .flagMadagascar, .flagMarshallIslands, .flagNorthMacedonia, .flagMali, .flagMyanmarBurma, .flagMongolia, .flagMacaoSarChina, .flagNorthernMarianaIslands, .flagMartinique, .flagMauritania, .flagMontserrat, .flagMalta, .flagMauritius, .flagMaldives, .flagMalawi, .flagMexico, .flagMalaysia, .flagMozambique, .flagNamibia, .flagNewCaledonia, .flagNiger, .flagNorfolkIsland, .flagNigeria, .flagNicaragua, .flagNetherlands, .flagNorway, .flagNepal, .flagNauru, .flagNiue, .flagNewZealand, .flagOman, .flagPanama, .flagPeru, .flagFrenchPolynesia, .flagPapuaNewGuinea, .flagPhilippines, .flagPakistan, .flagPoland, .flagStPierreMiquelon, .flagPitcairnIslands, .flagPuertoRico, .flagPalestinianTerritories, .flagPortugal, .flagPalau, .flagParaguay, .flagQatar, .flagReunion, .flagRomania, .flagSerbia, .flagRussia, .flagRwanda, .flagSaudiArabia, .flagSolomonIslands, .flagSeychelles, .flagSudan, .flagSweden, .flagSingapore, .flagStHelena, .flagSlovenia, .flagSvalbardJanMayen, .flagSlovakia, .flagSierraLeone, .flagSanMarino, .flagSenegal, .flagSomalia, .flagSuriname, .flagSouthSudan, .flagSaoTomePrincipe, .flagElSalvador, .flagSintMaarten, .flagSyria, .flagEswatini, .flagTristanDaCunha, .flagTurksCaicosIslands, .flagChad, .flagFrenchSouthernTerritories, .flagTogo, .flagThailand, .flagTajikistan, .flagTokelau, .flagTimorLeste, .flagTurkmenistan, .flagTunisia, .flagTonga, .flagTurkiye, .flagTrinidadTobago, .flagTuvalu, .flagTaiwan, .flagTanzania, .flagUkraine, .flagUganda, .flagUSOutlyingIslands, .flagUnitedNations, .flagUnitedStates, .flagUruguay, .flagUzbekistan, .flagVaticanCity, .flagStVincentGrenadines, .flagVenezuela, .flagBritishVirginIslands, .flagUSVirginIslands, .flagVietnam, .flagVanuatu, .flagWallisFutuna, .flagSamoa, .flagKosovo, .flagYemen, .flagMayotte, .flagSouthAfrica, .flagZambia, .flagZimbabwe, .flagEngland, .flagScotland, .flagWales]
      case .foodDrink:
            return [ .grapes, .melon, .watermelon, .tangerine, .lemon, .lime, .banana, .pineapple, .mango, .redApple, .greenApple, .pear, .peach, .cherries, .strawberry, .blueberries, .kiwiFruit, .tomato, .olive, .coconut, .avocado, .eggplant, .potato, .carrot, .earOfCorn, .hotPepper, .bellPepper, .cucumber, .leafyGreen, .broccoli, .garlic, .onion, .peanuts, .beans, .chestnut, .gingerRoot, .peaPod, .brownMushroom, .rootVegetable, .bread, .croissant, .baguetteBread, .flatbread, .pretzel, .bagel, .pancakes, .waffle, .cheeseWedge, .meatOnBone, .poultryLeg, .cutOfMeat, .bacon, .hamburger, .frenchFries, .pizza, .hotDog, .sandwich, .taco, .burrito, .tamale, .stuffedFlatbread, .falafel, .egg, .cooking, .shallowPanOfFood, .potOfFood, .fondue, .bowlWithSpoon, .greenSalad, .popcorn, .butter, .salt, .cannedFood, .bentoBox, .riceCracker, .riceBall, .cookedRice, .curryRice, .steamingBowl, .spaghetti, .roastedSweetPotato, .oden, .sushi, .friedShrimp, .fishCakeWithSwirl, .moonCake, .dango, .dumpling, .fortuneCookie, .takeoutBox, .softIceCream, .shavedIce, .iceCream, .doughnut, .cookie, .birthdayCake, .shortcake, .cupcake, .pie, .chocolateBar, .candy, .lollipop, .custard, .honeyPot, .babyBottle, .glassOfMilk, .hotBeverage, .teapot, .teacupWithoutHandle, .sake, .bottleWithPoppingCork, .wineGlass, .cocktailGlass, .tropicalDrink, .beerMug, .clinkingBeerMugs, .clinkingGlasses, .tumblerGlass, .pouringLiquid, .cupWithStraw, .bubbleTea, .beverageBox, .mate, .ice, .chopsticks, .forkAndKnifeWithPlate, .forkAndKnife, .spoon, .kitchenKnife, .jar, .amphora]
      case .objects:
            return [ .glasses, .sunglasses, .goggles, .labCoat, .safetyVest, .necktie, .tShirt, .jeans, .scarf, .gloves, .coat, .socks, .dress, .kimono, .sari, .onePieceSwimsuit, .briefs, .shorts, .bikini, .womanSClothes, .foldingHandFan, .purse, .handbag, .clutchBag, .shoppingBags, .backpack, .thongSandal, .manSShoe, .runningShoe, .hikingBoot, .flatShoe, .highHeeledShoe, .womanSSandal, .balletShoes, .womanSBoot, .hairPick, .crown, .womanSHat, .topHat, .graduationCap, .billedCap, .militaryHelmet, .rescueWorkerSHelmet, .prayerBeads, .lipstick, .ring, .gemStone, .mutedSpeaker, .speakerLowVolume, .speakerMediumVolume, .speakerHighVolume, .loudspeaker, .megaphone, .postalHorn, .bell, .bellWithSlash, .musicalScore, .musicalNote, .musicalNotes, .studioMicrophone, .levelSlider, .controlKnobs, .microphone, .headphone, .radio, .saxophone, .accordion, .guitar, .musicalKeyboard, .trumpet, .violin, .banjo, .drum, .longDrum, .maracas, .flute, .harp, .mobilePhone, .mobilePhoneWithArrow, .telephone, .telephoneReceiver, .pager, .faxMachine, .battery, .lowBattery, .electricPlug, .laptop, .desktopComputer, .printer, .keyboard, .computerMouse, .trackball, .computerDisk, .floppyDisk, .opticalDisk, .dvd, .abacus, .movieCamera, .filmFrames, .filmProjector, .clapperBoard, .television, .camera, .cameraWithFlash, .videoCamera, .videocassette, .magnifyingGlassTiltedLeft, .magnifyingGlassTiltedRight, .candle, .lightBulb, .flashlight, .redPaperLantern, .diyaLamp, .notebookWithDecorativeCover, .closedBook, .openBook, .greenBook, .blueBook, .orangeBook, .books, .notebook, .ledger, .pageWithCurl, .scroll, .pageFacingUp, .newspaper, .rolledUpNewspaper, .bookmarkTabs, .bookmark, .label, .moneyBag, .coin, .yenBanknote, .dollarBanknote, .euroBanknote, .poundBanknote, .moneyWithWings, .creditCard, .receipt, .chartIncreasingWithYen, .envelope, .eMail, .incomingEnvelope, .envelopeWithArrow, .outboxTray, .inboxTray, .package, .closedMailboxWithRaisedFlag, .closedMailboxWithLoweredFlag, .openMailboxWithRaisedFlag, .openMailboxWithLoweredFlag, .postbox, .ballotBoxWithBallot, .pencil, .blackNib, .fountainPen, .pen, .paintbrush, .crayon, .memo, .briefcase, .fileFolder, .openFileFolder, .cardIndexDividers, .calendar, .tearOffCalendar, .spiralNotepad, .spiralCalendar, .cardIndex, .chartIncreasing, .chartDecreasing, .barChart, .clipboard, .pushpin, .roundPushpin, .paperclip, .linkedPaperclips, .straightRuler, .triangularRuler, .scissors, .cardFileBox, .fileCabinet, .wastebasket, .locked, .unlocked, .lockedWithPen, .lockedWithKey, .key, .oldKey, .hammer, .axe, .pick, .hammerAndPick, .hammerAndWrench, .dagger, .crossedSwords, .bomb, .boomerang, .bowAndArrow, .shield, .carpentrySaw, .wrench, .screwdriver, .nutAndBolt, .gear, .clamp, .balanceScale, .whiteCane, .link, .brokenChain, .chains, .hook, .toolbox, .magnet, .ladder, .shovel, .alembic, .testTube, .petriDish, .dna, .microscope, .telescope, .satelliteAntenna, .syringe, .dropOfBlood, .pill, .adhesiveBandage, .crutch, .stethoscope, .xRay, .door, .elevator, .mirror, .window, .bed, .couchAndLamp, .chair, .toilet, .plunger, .shower, .bathtub, .mouseTrap, .razor, .lotionBottle, .safetyPin, .broom, .basket, .rollOfPaper, .bucket, .soap, .bubbles, .toothbrush, .sponge, .fireExtinguisher, .shoppingCart, .cigarette, .coffin, .headstone, .funeralUrn, .nazarAmulet, .hamsa, .moai, .placard, .identificationCard]
      case .peopleBody:
            return [ .wavingHand, .raisedBackOfHand, .handWithFingersSplayed, .raisedHand, .vulcanSalute, .rightwardsHand, .leftwardsHand, .palmDownHand, .palmUpHand, .leftwardsPushingHand, .rightwardsPushingHand, .okHand, .pinchedFingers, .pinchingHand, .victoryHand, .crossedFingers, .handWithIndexFingerAndThumbCrossed, .loveYouGesture, .signOfTheHorns, .callMeHand, .backhandIndexPointingLeft, .backhandIndexPointingRight, .backhandIndexPointingUp, .middleFinger, .backhandIndexPointingDown, .indexPointingUp, .indexPointingAtTheViewer, .thumbsUp, .thumbsDown, .raisedFist, .oncomingFist, .leftFacingFist, .rightFacingFist, .clappingHands, .raisingHands, .heartHands, .openHands, .palmsUpTogether, .handshake, .foldedHands, .writingHand, .nailPolish, .selfie, .flexedBiceps, .mechanicalArm, .mechanicalLeg, .leg, .foot, .ear, .earWithHearingAid, .nose, .brain, .anatomicalHeart, .lungs, .tooth, .bone, .eyes, .eye, .tongue, .mouth, .bitingLip, .baby, .child, .boy, .girl, .person, .personBlondHair, .man, .personBeard, .manBeard, .womanBeard, .manRedHair, .manCurlyHair, .manWhiteHair, .manBald, .woman, .womanRedHair, .personRedHair, .womanCurlyHair, .personCurlyHair, .womanWhiteHair, .personWhiteHair, .womanBald, .personBald, .womanBlondHair, .manBlondHair, .olderPerson, .oldMan, .oldWoman, .personFrowning, .manFrowning, .womanFrowning, .personPouting, .manPouting, .womanPouting, .personGesturingNo, .manGesturingNo, .womanGesturingNo, .personGesturingOk, .manGesturingOk, .womanGesturingOk, .personTippingHand, .manTippingHand, .womanTippingHand, .personRaisingHand, .manRaisingHand, .womanRaisingHand, .deafPerson, .deafMan, .deafWoman, .personBowing, .manBowing, .womanBowing, .personFacepalming, .manFacepalming, .womanFacepalming, .personShrugging, .manShrugging, .womanShrugging, .healthWorker, .manHealthWorker, .womanHealthWorker, .student, .manStudent, .womanStudent, .teacher, .manTeacher, .womanTeacher, .judge, .manJudge, .womanJudge, .farmer, .manFarmer, .womanFarmer, .cook, .manCook, .womanCook, .mechanic, .manMechanic, .womanMechanic, .factoryWorker, .manFactoryWorker, .womanFactoryWorker, .officeWorker, .manOfficeWorker, .womanOfficeWorker, .scientist, .manScientist, .womanScientist, .technologist, .manTechnologist, .womanTechnologist, .singer, .manSinger, .womanSinger, .artist, .manArtist, .womanArtist, .pilot, .manPilot, .womanPilot, .astronaut, .manAstronaut, .womanAstronaut, .firefighter, .manFirefighter, .womanFirefighter, .policeOfficer, .manPoliceOfficer, .womanPoliceOfficer, .detective, .manDetective, .womanDetective, .personGuard, .manGuard, .womanGuard, .ninja, .constructionWorker, .manConstructionWorker, .womanConstructionWorker, .personWithCrown, .prince, .princess, .personWearingTurban, .manWearingTurban, .womanWearingTurban, .personWithSkullcap, .womanWithHeadscarf, .personInTuxedo, .manInTuxedo, .womanInTuxedo, .personWithVeil, .manWithVeil, .womanWithVeil, .pregnantWoman, .pregnantMan, .pregnantPerson, .breastFeeding, .womanFeedingBaby, .manFeedingBaby, .personFeedingBaby, .babyAngel, .santaClaus, .mrsClaus, .mxClaus, .superhero, .manSuperhero, .womanSuperhero, .supervillain, .manSupervillain, .womanSupervillain, .mage, .manMage, .womanMage, .fairy, .manFairy, .womanFairy, .vampire, .manVampire, .womanVampire, .merperson, .merman, .mermaid, .elf, .manElf, .womanElf, .genie, .manGenie, .womanGenie, .zombie, .manZombie, .womanZombie, .troll, .personGettingMassage, .manGettingMassage, .womanGettingMassage, .personGettingHaircut, .manGettingHaircut, .womanGettingHaircut, .personWalking, .manWalking, .womanWalking, .personWalkingFacingRight, .womanWalkingFacingRight, .manWalkingFacingRight, .personStanding, .manStanding, .womanStanding, .personKneeling, .manKneeling, .womanKneeling, .personKneelingFacingRight, .womanKneelingFacingRight, .manKneelingFacingRight, .personWithWhiteCane, .personWithWhiteCaneFacingRight, .manWithWhiteCane, .manWithWhiteCaneFacingRight, .womanWithWhiteCane, .womanWithWhiteCaneFacingRight, .personInMotorizedWheelchair, .personInMotorizedWheelchairFacingRight, .manInMotorizedWheelchair, .manInMotorizedWheelchairFacingRight, .womanInMotorizedWheelchair, .womanInMotorizedWheelchairFacingRight, .personInManualWheelchair, .personInManualWheelchairFacingRight, .manInManualWheelchair, .manInManualWheelchairFacingRight, .womanInManualWheelchair, .womanInManualWheelchairFacingRight, .personRunning, .manRunning, .womanRunning, .personRunningFacingRight, .womanRunningFacingRight, .manRunningFacingRight, .womanDancing, .manDancing, .personInSuitLevitating, .peopleWithBunnyEars, .menWithBunnyEars, .womenWithBunnyEars, .personInSteamyRoom, .manInSteamyRoom, .womanInSteamyRoom, .personClimbing, .manClimbing, .womanClimbing, .personFencing, .horseRacing, .skier, .snowboarder, .personGolfing, .manGolfing, .womanGolfing, .personSurfing, .manSurfing, .womanSurfing, .personRowingBoat, .manRowingBoat, .womanRowingBoat, .personSwimming, .manSwimming, .womanSwimming, .personBouncingBall, .manBouncingBall, .womanBouncingBall, .personLiftingWeights, .manLiftingWeights, .womanLiftingWeights, .personBiking, .manBiking, .womanBiking, .personMountainBiking, .manMountainBiking, .womanMountainBiking, .personCartwheeling, .manCartwheeling, .womanCartwheeling, .peopleWrestling, .menWrestling, .womenWrestling, .personPlayingWaterPolo, .manPlayingWaterPolo, .womanPlayingWaterPolo, .personPlayingHandball, .manPlayingHandball, .womanPlayingHandball, .personJuggling, .manJuggling, .womanJuggling, .personInLotusPosition, .manInLotusPosition, .womanInLotusPosition, .personTakingBath, .personInBed, .peopleHoldingHands, .womenHoldingHands, .womanAndManHoldingHands, .menHoldingHands, .kiss, .kissWomanMan, .kissManMan, .kissWomanWoman, .coupleWithHeart, .coupleWithHeartWomanMan, .coupleWithHeartManMan, .coupleWithHeartWomanWoman, .familyManWomanBoy, .familyManWomanGirl, .familyManWomanGirlBoy, .familyManWomanBoyBoy, .familyManWomanGirlGirl, .familyManManBoy, .familyManManGirl, .familyManManGirlBoy, .familyManManBoyBoy, .familyManManGirlGirl, .familyWomanWomanBoy, .familyWomanWomanGirl, .familyWomanWomanGirlBoy, .familyWomanWomanBoyBoy, .familyWomanWomanGirlGirl, .familyManBoy, .familyManBoyBoy, .familyManGirl, .familyManGirlBoy, .familyManGirlGirl, .familyWomanBoy, .familyWomanBoyBoy, .familyWomanGirl, .familyWomanGirlBoy, .familyWomanGirlGirl, .speakingHead, .bustInSilhouette, .bustsInSilhouette, .peopleHugging, .family, .familyAdultAdultChild, .familyAdultAdultChildChild, .familyAdultChild, .familyAdultChildChild, .footprints, .fingerprint]
      case .smileysEmotion:
            return [ .grinningFace, .grinningFaceWithBigEyes, .grinningFaceWithSmilingEyes, .beamingFaceWithSmilingEyes, .grinningSquintingFace, .grinningFaceWithSweat, .rollingOnTheFloorLaughing, .faceWithTearsOfJoy, .slightlySmilingFace, .upsideDownFace, .meltingFace, .winkingFace, .smilingFaceWithSmilingEyes, .smilingFaceWithHalo, .smilingFaceWithHearts, .smilingFaceWithHeartEyes, .starStruck, .faceBlowingAKiss, .kissingFace, .smilingFace, .kissingFaceWithClosedEyes, .kissingFaceWithSmilingEyes, .smilingFaceWithTear, .faceSavoringFood, .faceWithTongue, .winkingFaceWithTongue, .zanyFace, .squintingFaceWithTongue, .moneyMouthFace, .smilingFaceWithOpenHands, .faceWithHandOverMouth, .faceWithOpenEyesAndHandOverMouth, .faceWithPeekingEye, .shushingFace, .thinkingFace, .salutingFace, .zipperMouthFace, .faceWithRaisedEyebrow, .neutralFace, .expressionlessFace, .faceWithoutMouth, .dottedLineFace, .faceInClouds, .smirkingFace, .unamusedFace, .faceWithRollingEyes, .grimacingFace, .faceExhaling, .lyingFace, .shakingFace, .headShakingHorizontally, .headShakingVertically, .relievedFace, .pensiveFace, .sleepyFace, .droolingFace, .sleepingFace, .faceWithBagsUnderEyes, .faceWithMedicalMask, .faceWithThermometer, .faceWithHeadBandage, .nauseatedFace, .faceVomiting, .sneezingFace, .hotFace, .coldFace, .woozyFace, .faceWithCrossedOutEyes, .faceWithSpiralEyes, .explodingHead, .cowboyHatFace, .partyingFace, .disguisedFace, .smilingFaceWithSunglasses, .nerdFace, .faceWithMonocle, .confusedFace, .faceWithDiagonalMouth, .worriedFace, .slightlyFrowningFace, .frowningFace, .faceWithOpenMouth, .hushedFace, .astonishedFace, .flushedFace, .pleadingFace, .faceHoldingBackTears, .frowningFaceWithOpenMouth, .anguishedFace, .fearfulFace, .anxiousFaceWithSweat, .sadButRelievedFace, .cryingFace, .loudlyCryingFace, .faceScreamingInFear, .confoundedFace, .perseveringFace, .disappointedFace, .downcastFaceWithSweat, .wearyFace, .tiredFace, .yawningFace, .faceWithSteamFromNose, .enragedFace, .angryFace, .faceWithSymbolsOnMouth, .smilingFaceWithHorns, .angryFaceWithHorns, .skull, .skullAndCrossbones, .pileOfPoo, .clownFace, .ogre, .goblin, .ghost, .alien, .alienMonster, .robot, .grinningCat, .grinningCatWithSmilingEyes, .catWithTearsOfJoy, .smilingCatWithHeartEyes, .catWithWrySmile, .kissingCat, .wearyCat, .cryingCat, .poutingCat, .seeNoEvilMonkey, .hearNoEvilMonkey, .speakNoEvilMonkey, .loveLetter, .heartWithArrow, .heartWithRibbon, .sparklingHeart, .growingHeart, .beatingHeart, .revolvingHearts, .twoHearts, .heartDecoration, .heartExclamation, .brokenHeart, .heartOnFire, .mendingHeart, .redHeart, .pinkHeart, .orangeHeart, .yellowHeart, .greenHeart, .blueHeart, .lightBlueHeart, .purpleHeart, .brownHeart, .blackHeart, .greyHeart, .whiteHeart, .kissMark, .hundredPoints, .angerSymbol, .collision, .dizzy, .sweatDroplets, .dashingAway, .hole, .speechBalloon, .eyeInSpeechBubble, .leftSpeechBubble, .rightAngerBubble, .thoughtBalloon, .zzz]
      case .symbols:
            return [ .atmSign, .litterInBinSign, .potableWater, .wheelchairSymbol, .menSRoom, .womenSRoom, .restroom, .babySymbol, .waterCloset, .passportControl, .customs, .baggageClaim, .leftLuggage, .warning, .childrenCrossing, .noEntry, .prohibited, .noBicycles, .noSmoking, .noLittering, .nonPotableWater, .noPedestrians, .noMobilePhones, .noOneUnderEighteen, .radioactive, .biohazard, .upArrow, .upRightArrow, .rightArrow, .downRightArrow, .downArrow, .downLeftArrow, .leftArrow, .upLeftArrow, .upDownArrow, .leftRightArrow, .rightArrowCurvingLeft, .leftArrowCurvingRight, .rightArrowCurvingUp, .rightArrowCurvingDown, .clockwiseVerticalArrows, .counterclockwiseArrowsButton, .backArrow, .endArrow, .onArrow, .soonArrow, .topArrow, .placeOfWorship, .atomSymbol, .om, .starOfDavid, .wheelOfDharma, .yinYang, .latinCross, .orthodoxCross, .starAndCrescent, .peaceSymbol, .menorah, .dottedSixPointedStar, .khanda, .aries, .taurus, .gemini, .cancer, .leo, .virgo, .libra, .scorpio, .sagittarius, .capricorn, .aquarius, .pisces, .ophiuchus, .shuffleTracksButton, .repeatButton, .repeatSingleButton, .playButton, .fastForwardButton, .nextTrackButton, .playOrPauseButton, .reverseButton, .fastReverseButton, .lastTrackButton, .upwardsButton, .fastUpButton, .downwardsButton, .fastDownButton, .pauseButton, .stopButton, .recordButton, .ejectButton, .cinema, .dimButton, .brightButton, .antennaBars, .wireless, .vibrationMode, .mobilePhoneOff, .femaleSign, .maleSign, .transgenderSymbol, .multiply, .plus, .minus, .divide, .heavyEqualsSign, .infinity, .doubleExclamationMark, .exclamationQuestionMark, .redQuestionMark, .whiteQuestionMark, .whiteExclamationMark, .redExclamationMark, .wavyDash, .currencyExchange, .heavyDollarSign, .medicalSymbol, .recyclingSymbol, .fleurDeLis, .tridentEmblem, .nameBadge, .japaneseSymbolForBeginner, .hollowRedCircle, .checkMarkButton, .checkBoxWithCheck, .checkMark, .crossMark, .crossMarkButton, .curlyLoop, .doubleCurlyLoop, .partAlternationMark, .eightSpokedAsterisk, .eightPointedStar, .sparkle, .copyright, .registered, .tradeMark, .splatter, .keycapRoute, .keycapStar, .keycap0, .keycap1, .keycap2, .keycap3, .keycap4, .keycap5, .keycap6, .keycap7, .keycap8, .keycap9, .keycap10, .inputLatinUppercase, .inputLatinLowercase, .inputNumbers, .inputSymbols, .inputLatinLetters, .aButtonBloodType, .abButtonBloodType, .bButtonBloodType, .clButton, .coolButton, .freeButton, .information, .idButton, .circledM, .newButton, .ngButton, .oButtonBloodType, .okButton, .pButton, .sosButton, .upButton, .vsButton, .japaneseHereButton, .japaneseServiceChargeButton, .japaneseMonthlyAmountButton, .japaneseNotFreeOfChargeButton, .japaneseReservedButton, .japaneseBargainButton, .japaneseDiscountButton, .japaneseFreeOfChargeButton, .japaneseProhibitedButton, .japaneseAcceptableButton, .japaneseApplicationButton, .japanesePassingGradeButton, .japaneseVacancyButton, .japaneseCongratulationsButton, .japaneseSecretButton, .japaneseOpenForBusinessButton, .japaneseNoVacancyButton, .redCircle, .orangeCircle, .yellowCircle, .greenCircle, .blueCircle, .purpleCircle, .brownCircle, .blackCircle, .whiteCircle, .redSquare, .orangeSquare, .yellowSquare, .greenSquare, .blueSquare, .purpleSquare, .brownSquare, .blackLargeSquare, .whiteLargeSquare, .blackMediumSquare, .whiteMediumSquare, .blackMediumSmallSquare, .whiteMediumSmallSquare, .blackSmallSquare, .whiteSmallSquare, .largeOrangeDiamond, .largeBlueDiamond, .smallOrangeDiamond, .smallBlueDiamond, .redTrianglePointedUp, .redTrianglePointedDown, .diamondWithADot, .radioButton, .whiteSquareButton, .blackSquareButton]
      case .travelPlaces:
            return [ .globeShowingEuropeAfrica, .globeShowingAmericas, .globeShowingAsiaAustralia, .globeWithMeridians, .worldMap, .mapOfJapan, .compass, .snowCappedMountain, .mountain, .volcano, .mountFuji, .camping, .beachWithUmbrella, .desert, .desertIsland, .nationalPark, .stadium, .classicalBuilding, .buildingConstruction, .brick, .rock, .wood, .hut, .houses, .derelictHouse, .house, .houseWithGarden, .officeBuilding, .japanesePostOffice, .postOffice, .hospital, .bank, .hotel, .loveHotel, .convenienceStore, .school, .departmentStore, .factory, .japaneseCastle, .castle, .wedding, .tokyoTower, .statueOfLiberty, .church, .mosque, .hinduTemple, .synagogue, .shintoShrine, .kaaba, .fountain, .tent, .foggy, .nightWithStars, .cityscape, .sunriseOverMountains, .sunrise, .cityscapeAtDusk, .sunset, .bridgeAtNight, .hotSprings, .carouselHorse, .playgroundSlide, .ferrisWheel, .rollerCoaster, .barberPole, .circusTent, .locomotive, .railwayCar, .highSpeedTrain, .bulletTrain, .train, .metro, .lightRail, .station, .tram, .monorail, .mountainRailway, .tramCar, .bus, .oncomingBus, .trolleybus, .minibus, .ambulance, .fireEngine, .policeCar, .oncomingPoliceCar, .taxi, .oncomingTaxi, .automobile, .oncomingAutomobile, .sportUtilityVehicle, .pickupTruck, .deliveryTruck, .articulatedLorry, .tractor, .racingCar, .motorcycle, .motorScooter, .manualWheelchair, .motorizedWheelchair, .autoRickshaw, .bicycle, .kickScooter, .skateboard, .rollerSkate, .busStop, .motorway, .railwayTrack, .oilDrum, .fuelPump, .wheel, .policeCarLight, .horizontalTrafficLight, .verticalTrafficLight, .stopSign, .construction, .anchor, .ringBuoy, .sailboat, .canoe, .speedboat, .passengerShip, .ferry, .motorBoat, .ship, .airplane, .smallAirplane, .airplaneDeparture, .airplaneArrival, .parachute, .seat, .helicopter, .suspensionRailway, .mountainCableway, .aerialTramway, .satellite, .rocket, .flyingSaucer, .bellhopBell, .luggage, .hourglassDone, .hourglassNotDone, .watch, .alarmClock, .stopwatch, .timerClock, .mantelpieceClock, .twelveOClock, .twelveThirty, .oneOClock, .oneThirty, .twoOClock, .twoThirty, .threeOClock, .threeThirty, .fourOClock, .fourThirty, .fiveOClock, .fiveThirty, .sixOClock, .sixThirty, .sevenOClock, .sevenThirty, .eightOClock, .eightThirty, .nineOClock, .nineThirty, .tenOClock, .tenThirty, .elevenOClock, .elevenThirty, .newMoon, .waxingCrescentMoon, .firstQuarterMoon, .waxingGibbousMoon, .fullMoon, .waningGibbousMoon, .lastQuarterMoon, .waningCrescentMoon, .crescentMoon, .newMoonFace, .firstQuarterMoonFace, .lastQuarterMoonFace, .thermometer, .sun, .fullMoonFace, .sunWithFace, .ringedPlanet, .star, .glowingStar, .shootingStar, .milkyWay, .cloud, .sunBehindCloud, .cloudWithLightningAndRain, .sunBehindSmallCloud, .sunBehindLargeCloud, .sunBehindRainCloud, .cloudWithRain, .cloudWithSnow, .cloudWithLightning, .tornado, .fog, .windFace, .cyclone, .rainbow, .closedUmbrella, .umbrella, .umbrellaWithRainDrops, .umbrellaOnGround, .highVoltage, .snowflake, .snowman, .snowmanWithoutSnow, .comet, .fire, .droplet, .waterWave]
        }
    }
}
