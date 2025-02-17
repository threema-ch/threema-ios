//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024-2025 Threema GmbH
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
	public var id: String { name }
    case hashKey = "#️⃣" // Category: symbols, Subcategory: keycap, Sort order: 1549
    case keycap = "*️⃣" // Category: symbols, Subcategory: keycap, Sort order: 1550
    case keycap0 = "0️⃣" // Category: symbols, Subcategory: keycap, Sort order: 1551
    case keycap1 = "1️⃣" // Category: symbols, Subcategory: keycap, Sort order: 1552
    case keycap2 = "2️⃣" // Category: symbols, Subcategory: keycap, Sort order: 1553
    case keycap3 = "3️⃣" // Category: symbols, Subcategory: keycap, Sort order: 1554
    case keycap4 = "4️⃣" // Category: symbols, Subcategory: keycap, Sort order: 1555
    case keycap5 = "5️⃣" // Category: symbols, Subcategory: keycap, Sort order: 1556
    case keycap6 = "6️⃣" // Category: symbols, Subcategory: keycap, Sort order: 1557
    case keycap7 = "7️⃣" // Category: symbols, Subcategory: keycap, Sort order: 1558
    case keycap8 = "8️⃣" // Category: symbols, Subcategory: keycap, Sort order: 1559
    case keycap9 = "9️⃣" // Category: symbols, Subcategory: keycap, Sort order: 1560
    case copyrightSign = "©️" // Category: symbols, Subcategory: other-symbol, Sort order: 1546
    case registeredSign = "®️" // Category: symbols, Subcategory: other-symbol, Sort order: 1547
    case mahjongTileRedDragon = "🀄" // Category: activities, Subcategory: game, Sort order: 1141
    case playingCardBlackJoker = "🃏" // Category: activities, Subcategory: game, Sort order: 1140
    case negativeSquaredLatinCapitalLetterA = "🅰️" // Category: symbols, Subcategory: alphanum, Sort order: 1567
    case negativeSquaredLatinCapitalLetterB = "🅱️" // Category: symbols, Subcategory: alphanum, Sort order: 1569
    case negativeSquaredLatinCapitalLetterO = "🅾️" // Category: symbols, Subcategory: alphanum, Sort order: 1578
    case negativeSquaredLatinCapitalLetterP = "🅿️" // Category: symbols, Subcategory: alphanum, Sort order: 1580
    case negativeSquaredAb = "🆎" // Category: symbols, Subcategory: alphanum, Sort order: 1568
    case squaredCl = "🆑" // Category: symbols, Subcategory: alphanum, Sort order: 1570
    case squaredCool = "🆒" // Category: symbols, Subcategory: alphanum, Sort order: 1571
    case squaredFree = "🆓" // Category: symbols, Subcategory: alphanum, Sort order: 1572
    case squaredId = "🆔" // Category: symbols, Subcategory: alphanum, Sort order: 1574
    case squaredNew = "🆕" // Category: symbols, Subcategory: alphanum, Sort order: 1576
    case squaredNg = "🆖" // Category: symbols, Subcategory: alphanum, Sort order: 1577
    case squaredOk = "🆗" // Category: symbols, Subcategory: alphanum, Sort order: 1579
    case squaredSos = "🆘" // Category: symbols, Subcategory: alphanum, Sort order: 1581
    case squaredUpWithExclamationMark = "🆙" // Category: symbols, Subcategory: alphanum, Sort order: 1582
    case squaredVs = "🆚" // Category: symbols, Subcategory: alphanum, Sort order: 1583
    case ascensionIslandFlag = "🇦🇨" // Category: flags, Subcategory: country-flag, Sort order: 1643
    case andorraFlag = "🇦🇩" // Category: flags, Subcategory: country-flag, Sort order: 1644
    case unitedArabEmiratesFlag = "🇦🇪" // Category: flags, Subcategory: country-flag, Sort order: 1645
    case afghanistanFlag = "🇦🇫" // Category: flags, Subcategory: country-flag, Sort order: 1646
    case antiguaBarbudaFlag = "🇦🇬" // Category: flags, Subcategory: country-flag, Sort order: 1647
    case anguillaFlag = "🇦🇮" // Category: flags, Subcategory: country-flag, Sort order: 1648
    case albaniaFlag = "🇦🇱" // Category: flags, Subcategory: country-flag, Sort order: 1649
    case armeniaFlag = "🇦🇲" // Category: flags, Subcategory: country-flag, Sort order: 1650
    case angolaFlag = "🇦🇴" // Category: flags, Subcategory: country-flag, Sort order: 1651
    case antarcticaFlag = "🇦🇶" // Category: flags, Subcategory: country-flag, Sort order: 1652
    case argentinaFlag = "🇦🇷" // Category: flags, Subcategory: country-flag, Sort order: 1653
    case americanSamoaFlag = "🇦🇸" // Category: flags, Subcategory: country-flag, Sort order: 1654
    case austriaFlag = "🇦🇹" // Category: flags, Subcategory: country-flag, Sort order: 1655
    case australiaFlag = "🇦🇺" // Category: flags, Subcategory: country-flag, Sort order: 1656
    case arubaFlag = "🇦🇼" // Category: flags, Subcategory: country-flag, Sort order: 1657
    case ålandIslandsFlag = "🇦🇽" // Category: flags, Subcategory: country-flag, Sort order: 1658
    case azerbaijanFlag = "🇦🇿" // Category: flags, Subcategory: country-flag, Sort order: 1659
    case bosniaHerzegovinaFlag = "🇧🇦" // Category: flags, Subcategory: country-flag, Sort order: 1660
    case barbadosFlag = "🇧🇧" // Category: flags, Subcategory: country-flag, Sort order: 1661
    case bangladeshFlag = "🇧🇩" // Category: flags, Subcategory: country-flag, Sort order: 1662
    case belgiumFlag = "🇧🇪" // Category: flags, Subcategory: country-flag, Sort order: 1663
    case burkinaFasoFlag = "🇧🇫" // Category: flags, Subcategory: country-flag, Sort order: 1664
    case bulgariaFlag = "🇧🇬" // Category: flags, Subcategory: country-flag, Sort order: 1665
    case bahrainFlag = "🇧🇭" // Category: flags, Subcategory: country-flag, Sort order: 1666
    case burundiFlag = "🇧🇮" // Category: flags, Subcategory: country-flag, Sort order: 1667
    case beninFlag = "🇧🇯" // Category: flags, Subcategory: country-flag, Sort order: 1668
    case stBarthélemyFlag = "🇧🇱" // Category: flags, Subcategory: country-flag, Sort order: 1669
    case bermudaFlag = "🇧🇲" // Category: flags, Subcategory: country-flag, Sort order: 1670
    case bruneiFlag = "🇧🇳" // Category: flags, Subcategory: country-flag, Sort order: 1671
    case boliviaFlag = "🇧🇴" // Category: flags, Subcategory: country-flag, Sort order: 1672
    case caribbeanNetherlandsFlag = "🇧🇶" // Category: flags, Subcategory: country-flag, Sort order: 1673
    case brazilFlag = "🇧🇷" // Category: flags, Subcategory: country-flag, Sort order: 1674
    case bahamasFlag = "🇧🇸" // Category: flags, Subcategory: country-flag, Sort order: 1675
    case bhutanFlag = "🇧🇹" // Category: flags, Subcategory: country-flag, Sort order: 1676
    case bouvetIslandFlag = "🇧🇻" // Category: flags, Subcategory: country-flag, Sort order: 1677
    case botswanaFlag = "🇧🇼" // Category: flags, Subcategory: country-flag, Sort order: 1678
    case belarusFlag = "🇧🇾" // Category: flags, Subcategory: country-flag, Sort order: 1679
    case belizeFlag = "🇧🇿" // Category: flags, Subcategory: country-flag, Sort order: 1680
    case canadaFlag = "🇨🇦" // Category: flags, Subcategory: country-flag, Sort order: 1681
    case cocosKeelingIslandsFlag = "🇨🇨" // Category: flags, Subcategory: country-flag, Sort order: 1682
    case congoKinshasaFlag = "🇨🇩" // Category: flags, Subcategory: country-flag, Sort order: 1683
    case centralAfricanRepublicFlag = "🇨🇫" // Category: flags, Subcategory: country-flag, Sort order: 1684
    case congoBrazzavilleFlag = "🇨🇬" // Category: flags, Subcategory: country-flag, Sort order: 1685
    case switzerlandFlag = "🇨🇭" // Category: flags, Subcategory: country-flag, Sort order: 1686
    case côteDivoireFlag = "🇨🇮" // Category: flags, Subcategory: country-flag, Sort order: 1687
    case cookIslandsFlag = "🇨🇰" // Category: flags, Subcategory: country-flag, Sort order: 1688
    case chileFlag = "🇨🇱" // Category: flags, Subcategory: country-flag, Sort order: 1689
    case cameroonFlag = "🇨🇲" // Category: flags, Subcategory: country-flag, Sort order: 1690
    case chinaFlag = "🇨🇳" // Category: flags, Subcategory: country-flag, Sort order: 1691
    case colombiaFlag = "🇨🇴" // Category: flags, Subcategory: country-flag, Sort order: 1692
    case clippertonIslandFlag = "🇨🇵" // Category: flags, Subcategory: country-flag, Sort order: 1693
    case costaRicaFlag = "🇨🇷" // Category: flags, Subcategory: country-flag, Sort order: 1694
    case cubaFlag = "🇨🇺" // Category: flags, Subcategory: country-flag, Sort order: 1695
    case capeVerdeFlag = "🇨🇻" // Category: flags, Subcategory: country-flag, Sort order: 1696
    case curaçaoFlag = "🇨🇼" // Category: flags, Subcategory: country-flag, Sort order: 1697
    case christmasIslandFlag = "🇨🇽" // Category: flags, Subcategory: country-flag, Sort order: 1698
    case cyprusFlag = "🇨🇾" // Category: flags, Subcategory: country-flag, Sort order: 1699
    case czechiaFlag = "🇨🇿" // Category: flags, Subcategory: country-flag, Sort order: 1700
    case germanyFlag = "🇩🇪" // Category: flags, Subcategory: country-flag, Sort order: 1701
    case diegoGarciaFlag = "🇩🇬" // Category: flags, Subcategory: country-flag, Sort order: 1702
    case djiboutiFlag = "🇩🇯" // Category: flags, Subcategory: country-flag, Sort order: 1703
    case denmarkFlag = "🇩🇰" // Category: flags, Subcategory: country-flag, Sort order: 1704
    case dominicaFlag = "🇩🇲" // Category: flags, Subcategory: country-flag, Sort order: 1705
    case dominicanRepublicFlag = "🇩🇴" // Category: flags, Subcategory: country-flag, Sort order: 1706
    case algeriaFlag = "🇩🇿" // Category: flags, Subcategory: country-flag, Sort order: 1707
    case ceutaMelillaFlag = "🇪🇦" // Category: flags, Subcategory: country-flag, Sort order: 1708
    case ecuadorFlag = "🇪🇨" // Category: flags, Subcategory: country-flag, Sort order: 1709
    case estoniaFlag = "🇪🇪" // Category: flags, Subcategory: country-flag, Sort order: 1710
    case egyptFlag = "🇪🇬" // Category: flags, Subcategory: country-flag, Sort order: 1711
    case westernSaharaFlag = "🇪🇭" // Category: flags, Subcategory: country-flag, Sort order: 1712
    case eritreaFlag = "🇪🇷" // Category: flags, Subcategory: country-flag, Sort order: 1713
    case spainFlag = "🇪🇸" // Category: flags, Subcategory: country-flag, Sort order: 1714
    case ethiopiaFlag = "🇪🇹" // Category: flags, Subcategory: country-flag, Sort order: 1715
    case europeanUnionFlag = "🇪🇺" // Category: flags, Subcategory: country-flag, Sort order: 1716
    case finlandFlag = "🇫🇮" // Category: flags, Subcategory: country-flag, Sort order: 1717
    case fijiFlag = "🇫🇯" // Category: flags, Subcategory: country-flag, Sort order: 1718
    case falklandIslandsFlag = "🇫🇰" // Category: flags, Subcategory: country-flag, Sort order: 1719
    case micronesiaFlag = "🇫🇲" // Category: flags, Subcategory: country-flag, Sort order: 1720
    case faroeIslandsFlag = "🇫🇴" // Category: flags, Subcategory: country-flag, Sort order: 1721
    case franceFlag = "🇫🇷" // Category: flags, Subcategory: country-flag, Sort order: 1722
    case gabonFlag = "🇬🇦" // Category: flags, Subcategory: country-flag, Sort order: 1723
    case unitedKingdomFlag = "🇬🇧" // Category: flags, Subcategory: country-flag, Sort order: 1724
    case grenadaFlag = "🇬🇩" // Category: flags, Subcategory: country-flag, Sort order: 1725
    case georgiaFlag = "🇬🇪" // Category: flags, Subcategory: country-flag, Sort order: 1726
    case frenchGuianaFlag = "🇬🇫" // Category: flags, Subcategory: country-flag, Sort order: 1727
    case guernseyFlag = "🇬🇬" // Category: flags, Subcategory: country-flag, Sort order: 1728
    case ghanaFlag = "🇬🇭" // Category: flags, Subcategory: country-flag, Sort order: 1729
    case gibraltarFlag = "🇬🇮" // Category: flags, Subcategory: country-flag, Sort order: 1730
    case greenlandFlag = "🇬🇱" // Category: flags, Subcategory: country-flag, Sort order: 1731
    case gambiaFlag = "🇬🇲" // Category: flags, Subcategory: country-flag, Sort order: 1732
    case guineaFlag = "🇬🇳" // Category: flags, Subcategory: country-flag, Sort order: 1733
    case guadeloupeFlag = "🇬🇵" // Category: flags, Subcategory: country-flag, Sort order: 1734
    case equatorialGuineaFlag = "🇬🇶" // Category: flags, Subcategory: country-flag, Sort order: 1735
    case greeceFlag = "🇬🇷" // Category: flags, Subcategory: country-flag, Sort order: 1736
    case southGeorgiaSouthSandwichIslandsFlag = "🇬🇸" // Category: flags, Subcategory: country-flag, Sort order: 1737
    case guatemalaFlag = "🇬🇹" // Category: flags, Subcategory: country-flag, Sort order: 1738
    case guamFlag = "🇬🇺" // Category: flags, Subcategory: country-flag, Sort order: 1739
    case guineabissauFlag = "🇬🇼" // Category: flags, Subcategory: country-flag, Sort order: 1740
    case guyanaFlag = "🇬🇾" // Category: flags, Subcategory: country-flag, Sort order: 1741
    case hongKongSarChinaFlag = "🇭🇰" // Category: flags, Subcategory: country-flag, Sort order: 1742
    case heardMcdonaldIslandsFlag = "🇭🇲" // Category: flags, Subcategory: country-flag, Sort order: 1743
    case hondurasFlag = "🇭🇳" // Category: flags, Subcategory: country-flag, Sort order: 1744
    case croatiaFlag = "🇭🇷" // Category: flags, Subcategory: country-flag, Sort order: 1745
    case haitiFlag = "🇭🇹" // Category: flags, Subcategory: country-flag, Sort order: 1746
    case hungaryFlag = "🇭🇺" // Category: flags, Subcategory: country-flag, Sort order: 1747
    case canaryIslandsFlag = "🇮🇨" // Category: flags, Subcategory: country-flag, Sort order: 1748
    case indonesiaFlag = "🇮🇩" // Category: flags, Subcategory: country-flag, Sort order: 1749
    case irelandFlag = "🇮🇪" // Category: flags, Subcategory: country-flag, Sort order: 1750
    case israelFlag = "🇮🇱" // Category: flags, Subcategory: country-flag, Sort order: 1751
    case isleOfManFlag = "🇮🇲" // Category: flags, Subcategory: country-flag, Sort order: 1752
    case indiaFlag = "🇮🇳" // Category: flags, Subcategory: country-flag, Sort order: 1753
    case britishIndianOceanTerritoryFlag = "🇮🇴" // Category: flags, Subcategory: country-flag, Sort order: 1754
    case iraqFlag = "🇮🇶" // Category: flags, Subcategory: country-flag, Sort order: 1755
    case iranFlag = "🇮🇷" // Category: flags, Subcategory: country-flag, Sort order: 1756
    case icelandFlag = "🇮🇸" // Category: flags, Subcategory: country-flag, Sort order: 1757
    case italyFlag = "🇮🇹" // Category: flags, Subcategory: country-flag, Sort order: 1758
    case jerseyFlag = "🇯🇪" // Category: flags, Subcategory: country-flag, Sort order: 1759
    case jamaicaFlag = "🇯🇲" // Category: flags, Subcategory: country-flag, Sort order: 1760
    case jordanFlag = "🇯🇴" // Category: flags, Subcategory: country-flag, Sort order: 1761
    case japanFlag = "🇯🇵" // Category: flags, Subcategory: country-flag, Sort order: 1762
    case kenyaFlag = "🇰🇪" // Category: flags, Subcategory: country-flag, Sort order: 1763
    case kyrgyzstanFlag = "🇰🇬" // Category: flags, Subcategory: country-flag, Sort order: 1764
    case cambodiaFlag = "🇰🇭" // Category: flags, Subcategory: country-flag, Sort order: 1765
    case kiribatiFlag = "🇰🇮" // Category: flags, Subcategory: country-flag, Sort order: 1766
    case comorosFlag = "🇰🇲" // Category: flags, Subcategory: country-flag, Sort order: 1767
    case stKittsNevisFlag = "🇰🇳" // Category: flags, Subcategory: country-flag, Sort order: 1768
    case northKoreaFlag = "🇰🇵" // Category: flags, Subcategory: country-flag, Sort order: 1769
    case southKoreaFlag = "🇰🇷" // Category: flags, Subcategory: country-flag, Sort order: 1770
    case kuwaitFlag = "🇰🇼" // Category: flags, Subcategory: country-flag, Sort order: 1771
    case caymanIslandsFlag = "🇰🇾" // Category: flags, Subcategory: country-flag, Sort order: 1772
    case kazakhstanFlag = "🇰🇿" // Category: flags, Subcategory: country-flag, Sort order: 1773
    case laosFlag = "🇱🇦" // Category: flags, Subcategory: country-flag, Sort order: 1774
    case lebanonFlag = "🇱🇧" // Category: flags, Subcategory: country-flag, Sort order: 1775
    case stLuciaFlag = "🇱🇨" // Category: flags, Subcategory: country-flag, Sort order: 1776
    case liechtensteinFlag = "🇱🇮" // Category: flags, Subcategory: country-flag, Sort order: 1777
    case sriLankaFlag = "🇱🇰" // Category: flags, Subcategory: country-flag, Sort order: 1778
    case liberiaFlag = "🇱🇷" // Category: flags, Subcategory: country-flag, Sort order: 1779
    case lesothoFlag = "🇱🇸" // Category: flags, Subcategory: country-flag, Sort order: 1780
    case lithuaniaFlag = "🇱🇹" // Category: flags, Subcategory: country-flag, Sort order: 1781
    case luxembourgFlag = "🇱🇺" // Category: flags, Subcategory: country-flag, Sort order: 1782
    case latviaFlag = "🇱🇻" // Category: flags, Subcategory: country-flag, Sort order: 1783
    case libyaFlag = "🇱🇾" // Category: flags, Subcategory: country-flag, Sort order: 1784
    case moroccoFlag = "🇲🇦" // Category: flags, Subcategory: country-flag, Sort order: 1785
    case monacoFlag = "🇲🇨" // Category: flags, Subcategory: country-flag, Sort order: 1786
    case moldovaFlag = "🇲🇩" // Category: flags, Subcategory: country-flag, Sort order: 1787
    case montenegroFlag = "🇲🇪" // Category: flags, Subcategory: country-flag, Sort order: 1788
    case stMartinFlag = "🇲🇫" // Category: flags, Subcategory: country-flag, Sort order: 1789
    case madagascarFlag = "🇲🇬" // Category: flags, Subcategory: country-flag, Sort order: 1790
    case marshallIslandsFlag = "🇲🇭" // Category: flags, Subcategory: country-flag, Sort order: 1791
    case northMacedoniaFlag = "🇲🇰" // Category: flags, Subcategory: country-flag, Sort order: 1792
    case maliFlag = "🇲🇱" // Category: flags, Subcategory: country-flag, Sort order: 1793
    case myanmarBurmaFlag = "🇲🇲" // Category: flags, Subcategory: country-flag, Sort order: 1794
    case mongoliaFlag = "🇲🇳" // Category: flags, Subcategory: country-flag, Sort order: 1795
    case macaoSarChinaFlag = "🇲🇴" // Category: flags, Subcategory: country-flag, Sort order: 1796
    case northernMarianaIslandsFlag = "🇲🇵" // Category: flags, Subcategory: country-flag, Sort order: 1797
    case martiniqueFlag = "🇲🇶" // Category: flags, Subcategory: country-flag, Sort order: 1798
    case mauritaniaFlag = "🇲🇷" // Category: flags, Subcategory: country-flag, Sort order: 1799
    case montserratFlag = "🇲🇸" // Category: flags, Subcategory: country-flag, Sort order: 1800
    case maltaFlag = "🇲🇹" // Category: flags, Subcategory: country-flag, Sort order: 1801
    case mauritiusFlag = "🇲🇺" // Category: flags, Subcategory: country-flag, Sort order: 1802
    case maldivesFlag = "🇲🇻" // Category: flags, Subcategory: country-flag, Sort order: 1803
    case malawiFlag = "🇲🇼" // Category: flags, Subcategory: country-flag, Sort order: 1804
    case mexicoFlag = "🇲🇽" // Category: flags, Subcategory: country-flag, Sort order: 1805
    case malaysiaFlag = "🇲🇾" // Category: flags, Subcategory: country-flag, Sort order: 1806
    case mozambiqueFlag = "🇲🇿" // Category: flags, Subcategory: country-flag, Sort order: 1807
    case namibiaFlag = "🇳🇦" // Category: flags, Subcategory: country-flag, Sort order: 1808
    case newCaledoniaFlag = "🇳🇨" // Category: flags, Subcategory: country-flag, Sort order: 1809
    case nigerFlag = "🇳🇪" // Category: flags, Subcategory: country-flag, Sort order: 1810
    case norfolkIslandFlag = "🇳🇫" // Category: flags, Subcategory: country-flag, Sort order: 1811
    case nigeriaFlag = "🇳🇬" // Category: flags, Subcategory: country-flag, Sort order: 1812
    case nicaraguaFlag = "🇳🇮" // Category: flags, Subcategory: country-flag, Sort order: 1813
    case netherlandsFlag = "🇳🇱" // Category: flags, Subcategory: country-flag, Sort order: 1814
    case norwayFlag = "🇳🇴" // Category: flags, Subcategory: country-flag, Sort order: 1815
    case nepalFlag = "🇳🇵" // Category: flags, Subcategory: country-flag, Sort order: 1816
    case nauruFlag = "🇳🇷" // Category: flags, Subcategory: country-flag, Sort order: 1817
    case niueFlag = "🇳🇺" // Category: flags, Subcategory: country-flag, Sort order: 1818
    case newZealandFlag = "🇳🇿" // Category: flags, Subcategory: country-flag, Sort order: 1819
    case omanFlag = "🇴🇲" // Category: flags, Subcategory: country-flag, Sort order: 1820
    case panamaFlag = "🇵🇦" // Category: flags, Subcategory: country-flag, Sort order: 1821
    case peruFlag = "🇵🇪" // Category: flags, Subcategory: country-flag, Sort order: 1822
    case frenchPolynesiaFlag = "🇵🇫" // Category: flags, Subcategory: country-flag, Sort order: 1823
    case papuaNewGuineaFlag = "🇵🇬" // Category: flags, Subcategory: country-flag, Sort order: 1824
    case philippinesFlag = "🇵🇭" // Category: flags, Subcategory: country-flag, Sort order: 1825
    case pakistanFlag = "🇵🇰" // Category: flags, Subcategory: country-flag, Sort order: 1826
    case polandFlag = "🇵🇱" // Category: flags, Subcategory: country-flag, Sort order: 1827
    case stPierreMiquelonFlag = "🇵🇲" // Category: flags, Subcategory: country-flag, Sort order: 1828
    case pitcairnIslandsFlag = "🇵🇳" // Category: flags, Subcategory: country-flag, Sort order: 1829
    case puertoRicoFlag = "🇵🇷" // Category: flags, Subcategory: country-flag, Sort order: 1830
    case palestinianTerritoriesFlag = "🇵🇸" // Category: flags, Subcategory: country-flag, Sort order: 1831
    case portugalFlag = "🇵🇹" // Category: flags, Subcategory: country-flag, Sort order: 1832
    case palauFlag = "🇵🇼" // Category: flags, Subcategory: country-flag, Sort order: 1833
    case paraguayFlag = "🇵🇾" // Category: flags, Subcategory: country-flag, Sort order: 1834
    case qatarFlag = "🇶🇦" // Category: flags, Subcategory: country-flag, Sort order: 1835
    case réunionFlag = "🇷🇪" // Category: flags, Subcategory: country-flag, Sort order: 1836
    case romaniaFlag = "🇷🇴" // Category: flags, Subcategory: country-flag, Sort order: 1837
    case serbiaFlag = "🇷🇸" // Category: flags, Subcategory: country-flag, Sort order: 1838
    case russiaFlag = "🇷🇺" // Category: flags, Subcategory: country-flag, Sort order: 1839
    case rwandaFlag = "🇷🇼" // Category: flags, Subcategory: country-flag, Sort order: 1840
    case saudiArabiaFlag = "🇸🇦" // Category: flags, Subcategory: country-flag, Sort order: 1841
    case solomonIslandsFlag = "🇸🇧" // Category: flags, Subcategory: country-flag, Sort order: 1842
    case seychellesFlag = "🇸🇨" // Category: flags, Subcategory: country-flag, Sort order: 1843
    case sudanFlag = "🇸🇩" // Category: flags, Subcategory: country-flag, Sort order: 1844
    case swedenFlag = "🇸🇪" // Category: flags, Subcategory: country-flag, Sort order: 1845
    case singaporeFlag = "🇸🇬" // Category: flags, Subcategory: country-flag, Sort order: 1846
    case stHelenaFlag = "🇸🇭" // Category: flags, Subcategory: country-flag, Sort order: 1847
    case sloveniaFlag = "🇸🇮" // Category: flags, Subcategory: country-flag, Sort order: 1848
    case svalbardJanMayenFlag = "🇸🇯" // Category: flags, Subcategory: country-flag, Sort order: 1849
    case slovakiaFlag = "🇸🇰" // Category: flags, Subcategory: country-flag, Sort order: 1850
    case sierraLeoneFlag = "🇸🇱" // Category: flags, Subcategory: country-flag, Sort order: 1851
    case sanMarinoFlag = "🇸🇲" // Category: flags, Subcategory: country-flag, Sort order: 1852
    case senegalFlag = "🇸🇳" // Category: flags, Subcategory: country-flag, Sort order: 1853
    case somaliaFlag = "🇸🇴" // Category: flags, Subcategory: country-flag, Sort order: 1854
    case surinameFlag = "🇸🇷" // Category: flags, Subcategory: country-flag, Sort order: 1855
    case southSudanFlag = "🇸🇸" // Category: flags, Subcategory: country-flag, Sort order: 1856
    case sãoToméPríncipeFlag = "🇸🇹" // Category: flags, Subcategory: country-flag, Sort order: 1857
    case elSalvadorFlag = "🇸🇻" // Category: flags, Subcategory: country-flag, Sort order: 1858
    case sintMaartenFlag = "🇸🇽" // Category: flags, Subcategory: country-flag, Sort order: 1859
    case syriaFlag = "🇸🇾" // Category: flags, Subcategory: country-flag, Sort order: 1860
    case eswatiniFlag = "🇸🇿" // Category: flags, Subcategory: country-flag, Sort order: 1861
    case tristanDaCunhaFlag = "🇹🇦" // Category: flags, Subcategory: country-flag, Sort order: 1862
    case turksCaicosIslandsFlag = "🇹🇨" // Category: flags, Subcategory: country-flag, Sort order: 1863
    case chadFlag = "🇹🇩" // Category: flags, Subcategory: country-flag, Sort order: 1864
    case frenchSouthernTerritoriesFlag = "🇹🇫" // Category: flags, Subcategory: country-flag, Sort order: 1865
    case togoFlag = "🇹🇬" // Category: flags, Subcategory: country-flag, Sort order: 1866
    case thailandFlag = "🇹🇭" // Category: flags, Subcategory: country-flag, Sort order: 1867
    case tajikistanFlag = "🇹🇯" // Category: flags, Subcategory: country-flag, Sort order: 1868
    case tokelauFlag = "🇹🇰" // Category: flags, Subcategory: country-flag, Sort order: 1869
    case timorlesteFlag = "🇹🇱" // Category: flags, Subcategory: country-flag, Sort order: 1870
    case turkmenistanFlag = "🇹🇲" // Category: flags, Subcategory: country-flag, Sort order: 1871
    case tunisiaFlag = "🇹🇳" // Category: flags, Subcategory: country-flag, Sort order: 1872
    case tongaFlag = "🇹🇴" // Category: flags, Subcategory: country-flag, Sort order: 1873
    case türkiyeFlag = "🇹🇷" // Category: flags, Subcategory: country-flag, Sort order: 1874
    case trinidadTobagoFlag = "🇹🇹" // Category: flags, Subcategory: country-flag, Sort order: 1875
    case tuvaluFlag = "🇹🇻" // Category: flags, Subcategory: country-flag, Sort order: 1876
    case taiwanFlag = "🇹🇼" // Category: flags, Subcategory: country-flag, Sort order: 1877
    case tanzaniaFlag = "🇹🇿" // Category: flags, Subcategory: country-flag, Sort order: 1878
    case ukraineFlag = "🇺🇦" // Category: flags, Subcategory: country-flag, Sort order: 1879
    case ugandaFlag = "🇺🇬" // Category: flags, Subcategory: country-flag, Sort order: 1880
    case usOutlyingIslandsFlag = "🇺🇲" // Category: flags, Subcategory: country-flag, Sort order: 1881
    case unitedNationsFlag = "🇺🇳" // Category: flags, Subcategory: country-flag, Sort order: 1882
    case unitedStatesFlag = "🇺🇸" // Category: flags, Subcategory: country-flag, Sort order: 1883
    case uruguayFlag = "🇺🇾" // Category: flags, Subcategory: country-flag, Sort order: 1884
    case uzbekistanFlag = "🇺🇿" // Category: flags, Subcategory: country-flag, Sort order: 1885
    case vaticanCityFlag = "🇻🇦" // Category: flags, Subcategory: country-flag, Sort order: 1886
    case stVincentGrenadinesFlag = "🇻🇨" // Category: flags, Subcategory: country-flag, Sort order: 1887
    case venezuelaFlag = "🇻🇪" // Category: flags, Subcategory: country-flag, Sort order: 1888
    case britishVirginIslandsFlag = "🇻🇬" // Category: flags, Subcategory: country-flag, Sort order: 1889
    case usVirginIslandsFlag = "🇻🇮" // Category: flags, Subcategory: country-flag, Sort order: 1890
    case vietnamFlag = "🇻🇳" // Category: flags, Subcategory: country-flag, Sort order: 1891
    case vanuatuFlag = "🇻🇺" // Category: flags, Subcategory: country-flag, Sort order: 1892
    case wallisFutunaFlag = "🇼🇫" // Category: flags, Subcategory: country-flag, Sort order: 1893
    case samoaFlag = "🇼🇸" // Category: flags, Subcategory: country-flag, Sort order: 1894
    case kosovoFlag = "🇽🇰" // Category: flags, Subcategory: country-flag, Sort order: 1895
    case yemenFlag = "🇾🇪" // Category: flags, Subcategory: country-flag, Sort order: 1896
    case mayotteFlag = "🇾🇹" // Category: flags, Subcategory: country-flag, Sort order: 1897
    case southAfricaFlag = "🇿🇦" // Category: flags, Subcategory: country-flag, Sort order: 1898
    case zambiaFlag = "🇿🇲" // Category: flags, Subcategory: country-flag, Sort order: 1899
    case zimbabweFlag = "🇿🇼" // Category: flags, Subcategory: country-flag, Sort order: 1900
    case squaredKatakanaKoko = "🈁" // Category: symbols, Subcategory: alphanum, Sort order: 1584
    case squaredKatakanaSa = "🈂️" // Category: symbols, Subcategory: alphanum, Sort order: 1585
    case squaredCjkUnifiedIdeograph7121 = "🈚" // Category: symbols, Subcategory: alphanum, Sort order: 1591
    case squaredCjkUnifiedIdeograph6307 = "🈯" // Category: symbols, Subcategory: alphanum, Sort order: 1588
    case squaredCjkUnifiedIdeograph7981 = "🈲" // Category: symbols, Subcategory: alphanum, Sort order: 1592
    case squaredCjkUnifiedIdeograph7A7A = "🈳" // Category: symbols, Subcategory: alphanum, Sort order: 1596
    case squaredCjkUnifiedIdeograph5408 = "🈴" // Category: symbols, Subcategory: alphanum, Sort order: 1595
    case squaredCjkUnifiedIdeograph6E80 = "🈵" // Category: symbols, Subcategory: alphanum, Sort order: 1600
    case squaredCjkUnifiedIdeograph6709 = "🈶" // Category: symbols, Subcategory: alphanum, Sort order: 1587
    case squaredCjkUnifiedIdeograph6708 = "🈷️" // Category: symbols, Subcategory: alphanum, Sort order: 1586
    case squaredCjkUnifiedIdeograph7533 = "🈸" // Category: symbols, Subcategory: alphanum, Sort order: 1594
    case squaredCjkUnifiedIdeograph5272 = "🈹" // Category: symbols, Subcategory: alphanum, Sort order: 1590
    case squaredCjkUnifiedIdeograph55B6 = "🈺" // Category: symbols, Subcategory: alphanum, Sort order: 1599
    case circledIdeographAdvantage = "🉐" // Category: symbols, Subcategory: alphanum, Sort order: 1589
    case circledIdeographAccept = "🉑" // Category: symbols, Subcategory: alphanum, Sort order: 1593
    case cyclone = "🌀" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1051
    case foggy = "🌁" // Category: travelPlaces, Subcategory: place-other, Sort order: 898
    case closedUmbrella = "🌂" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1053
    case nightWithStars = "🌃" // Category: travelPlaces, Subcategory: place-other, Sort order: 899
    case sunriseOverMountains = "🌄" // Category: travelPlaces, Subcategory: place-other, Sort order: 901
    case sunrise = "🌅" // Category: travelPlaces, Subcategory: place-other, Sort order: 902
    case cityscapeAtDusk = "🌆" // Category: travelPlaces, Subcategory: place-other, Sort order: 903
    case sunsetOverBuildings = "🌇" // Category: travelPlaces, Subcategory: place-other, Sort order: 904
    case rainbow = "🌈" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1052
    case bridgeAtNight = "🌉" // Category: travelPlaces, Subcategory: place-other, Sort order: 905
    case waterWave = "🌊" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1064
    case volcano = "🌋" // Category: travelPlaces, Subcategory: place-geographic, Sort order: 856
    case milkyWay = "🌌" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1038
    case earthGlobeEuropeafrica = "🌍" // Category: travelPlaces, Subcategory: place-map, Sort order: 847
    case earthGlobeAmericas = "🌎" // Category: travelPlaces, Subcategory: place-map, Sort order: 848
    case earthGlobeAsiaaustralia = "🌏" // Category: travelPlaces, Subcategory: place-map, Sort order: 849
    case globeWithMeridians = "🌐" // Category: travelPlaces, Subcategory: place-map, Sort order: 850
    case newMoonSymbol = "🌑" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1018
    case waxingCrescentMoonSymbol = "🌒" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1019
    case firstQuarterMoonSymbol = "🌓" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1020
    case waxingGibbousMoonSymbol = "🌔" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1021
    case fullMoonSymbol = "🌕" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1022
    case waningGibbousMoonSymbol = "🌖" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1023
    case lastQuarterMoonSymbol = "🌗" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1024
    case waningCrescentMoonSymbol = "🌘" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1025
    case crescentMoon = "🌙" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1026
    case newMoonWithFace = "🌚" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1027
    case firstQuarterMoonWithFace = "🌛" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1028
    case lastQuarterMoonWithFace = "🌜" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1029
    case fullMoonWithFace = "🌝" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1032
    case sunWithFace = "🌞" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1033
    case glowingStar = "🌟" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1036
    case shootingStar = "🌠" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1037
    case thermometer = "🌡️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1030
    case sunBehindSmallCloud = "🌤️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1042
    case sunBehindLargeCloud = "🌥️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1043
    case sunBehindRainCloud = "🌦️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1044
    case cloudWithRain = "🌧️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1045
    case cloudWithSnow = "🌨️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1046
    case cloudWithLightning = "🌩️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1047
    case tornado = "🌪️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1048
    case fog = "🌫️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1049
    case windFace = "🌬️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1050
    case hotDog = "🌭" // Category: foodDrink, Subcategory: food-prepared, Sort order: 766
    case taco = "🌮" // Category: foodDrink, Subcategory: food-prepared, Sort order: 768
    case burrito = "🌯" // Category: foodDrink, Subcategory: food-prepared, Sort order: 769
    case chestnut = "🌰" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 746
    case seedling = "🌱" // Category: animalsNature, Subcategory: plant-other, Sort order: 696
    case evergreenTree = "🌲" // Category: animalsNature, Subcategory: plant-other, Sort order: 698
    case deciduousTree = "🌳" // Category: animalsNature, Subcategory: plant-other, Sort order: 699
    case palmTree = "🌴" // Category: animalsNature, Subcategory: plant-other, Sort order: 700
    case cactus = "🌵" // Category: animalsNature, Subcategory: plant-other, Sort order: 701
    case hotPepper = "🌶️" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 737
    case tulip = "🌷" // Category: animalsNature, Subcategory: plant-flower, Sort order: 694
    case cherryBlossom = "🌸" // Category: animalsNature, Subcategory: plant-flower, Sort order: 685
    case rose = "🌹" // Category: animalsNature, Subcategory: plant-flower, Sort order: 689
    case hibiscus = "🌺" // Category: animalsNature, Subcategory: plant-flower, Sort order: 691
    case sunflower = "🌻" // Category: animalsNature, Subcategory: plant-flower, Sort order: 692
    case blossom = "🌼" // Category: animalsNature, Subcategory: plant-flower, Sort order: 693
    case earOfMaize = "🌽" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 736
    case earOfRice = "🌾" // Category: animalsNature, Subcategory: plant-other, Sort order: 702
    case herb = "🌿" // Category: animalsNature, Subcategory: plant-other, Sort order: 703
    case fourLeafClover = "🍀" // Category: animalsNature, Subcategory: plant-other, Sort order: 705
    case mapleLeaf = "🍁" // Category: animalsNature, Subcategory: plant-other, Sort order: 706
    case fallenLeaf = "🍂" // Category: animalsNature, Subcategory: plant-other, Sort order: 707
    case leafFlutteringInWind = "🍃" // Category: animalsNature, Subcategory: plant-other, Sort order: 708
    case brownMushroom = "🍄‍🟫" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 749
    case mushroom = "🍄" // Category: animalsNature, Subcategory: plant-other, Sort order: 711
    case tomato = "🍅" // Category: foodDrink, Subcategory: food-fruit, Sort order: 729
    case aubergine = "🍆" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 733
    case grapes = "🍇" // Category: foodDrink, Subcategory: food-fruit, Sort order: 712
    case melon = "🍈" // Category: foodDrink, Subcategory: food-fruit, Sort order: 713
    case watermelon = "🍉" // Category: foodDrink, Subcategory: food-fruit, Sort order: 714
    case tangerine = "🍊" // Category: foodDrink, Subcategory: food-fruit, Sort order: 715
    case lime = "🍋‍🟩" // Category: foodDrink, Subcategory: food-fruit, Sort order: 717
    case lemon = "🍋" // Category: foodDrink, Subcategory: food-fruit, Sort order: 716
    case banana = "🍌" // Category: foodDrink, Subcategory: food-fruit, Sort order: 718
    case pineapple = "🍍" // Category: foodDrink, Subcategory: food-fruit, Sort order: 719
    case redApple = "🍎" // Category: foodDrink, Subcategory: food-fruit, Sort order: 721
    case greenApple = "🍏" // Category: foodDrink, Subcategory: food-fruit, Sort order: 722
    case pear = "🍐" // Category: foodDrink, Subcategory: food-fruit, Sort order: 723
    case peach = "🍑" // Category: foodDrink, Subcategory: food-fruit, Sort order: 724
    case cherries = "🍒" // Category: foodDrink, Subcategory: food-fruit, Sort order: 725
    case strawberry = "🍓" // Category: foodDrink, Subcategory: food-fruit, Sort order: 726
    case hamburger = "🍔" // Category: foodDrink, Subcategory: food-prepared, Sort order: 763
    case sliceOfPizza = "🍕" // Category: foodDrink, Subcategory: food-prepared, Sort order: 765
    case meatOnBone = "🍖" // Category: foodDrink, Subcategory: food-prepared, Sort order: 759
    case poultryLeg = "🍗" // Category: foodDrink, Subcategory: food-prepared, Sort order: 760
    case riceCracker = "🍘" // Category: foodDrink, Subcategory: food-asian, Sort order: 785
    case riceBall = "🍙" // Category: foodDrink, Subcategory: food-asian, Sort order: 786
    case cookedRice = "🍚" // Category: foodDrink, Subcategory: food-asian, Sort order: 787
    case curryAndRice = "🍛" // Category: foodDrink, Subcategory: food-asian, Sort order: 788
    case steamingBowl = "🍜" // Category: foodDrink, Subcategory: food-asian, Sort order: 789
    case spaghetti = "🍝" // Category: foodDrink, Subcategory: food-asian, Sort order: 790
    case bread = "🍞" // Category: foodDrink, Subcategory: food-prepared, Sort order: 750
    case frenchFries = "🍟" // Category: foodDrink, Subcategory: food-prepared, Sort order: 764
    case roastedSweetPotato = "🍠" // Category: foodDrink, Subcategory: food-asian, Sort order: 791
    case dango = "🍡" // Category: foodDrink, Subcategory: food-asian, Sort order: 797
    case oden = "🍢" // Category: foodDrink, Subcategory: food-asian, Sort order: 792
    case sushi = "🍣" // Category: foodDrink, Subcategory: food-asian, Sort order: 793
    case friedShrimp = "🍤" // Category: foodDrink, Subcategory: food-asian, Sort order: 794
    case fishCakeWithSwirlDesign = "🍥" // Category: foodDrink, Subcategory: food-asian, Sort order: 795
    case softIceCream = "🍦" // Category: foodDrink, Subcategory: food-sweet, Sort order: 806
    case shavedIce = "🍧" // Category: foodDrink, Subcategory: food-sweet, Sort order: 807
    case iceCream = "🍨" // Category: foodDrink, Subcategory: food-sweet, Sort order: 808
    case doughnut = "🍩" // Category: foodDrink, Subcategory: food-sweet, Sort order: 809
    case cookie = "🍪" // Category: foodDrink, Subcategory: food-sweet, Sort order: 810
    case chocolateBar = "🍫" // Category: foodDrink, Subcategory: food-sweet, Sort order: 815
    case candy = "🍬" // Category: foodDrink, Subcategory: food-sweet, Sort order: 816
    case lollipop = "🍭" // Category: foodDrink, Subcategory: food-sweet, Sort order: 817
    case custard = "🍮" // Category: foodDrink, Subcategory: food-sweet, Sort order: 818
    case honeyPot = "🍯" // Category: foodDrink, Subcategory: food-sweet, Sort order: 819
    case shortcake = "🍰" // Category: foodDrink, Subcategory: food-sweet, Sort order: 812
    case bentoBox = "🍱" // Category: foodDrink, Subcategory: food-asian, Sort order: 784
    case potOfFood = "🍲" // Category: foodDrink, Subcategory: food-prepared, Sort order: 776
    case cooking = "🍳" // Category: foodDrink, Subcategory: food-prepared, Sort order: 774
    case forkAndKnife = "🍴" // Category: foodDrink, Subcategory: dishware, Sort order: 842
    case teacupWithoutHandle = "🍵" // Category: foodDrink, Subcategory: drink, Sort order: 824
    case sakeBottleAndCup = "🍶" // Category: foodDrink, Subcategory: drink, Sort order: 825
    case wineGlass = "🍷" // Category: foodDrink, Subcategory: drink, Sort order: 827
    case cocktailGlass = "🍸" // Category: foodDrink, Subcategory: drink, Sort order: 828
    case tropicalDrink = "🍹" // Category: foodDrink, Subcategory: drink, Sort order: 829
    case beerMug = "🍺" // Category: foodDrink, Subcategory: drink, Sort order: 830
    case clinkingBeerMugs = "🍻" // Category: foodDrink, Subcategory: drink, Sort order: 831
    case babyBottle = "🍼" // Category: foodDrink, Subcategory: drink, Sort order: 820
    case forkAndKnifeWithPlate = "🍽️" // Category: foodDrink, Subcategory: dishware, Sort order: 841
    case bottleWithPoppingCork = "🍾" // Category: foodDrink, Subcategory: drink, Sort order: 826
    case popcorn = "🍿" // Category: foodDrink, Subcategory: food-prepared, Sort order: 780
    case ribbon = "🎀" // Category: activities, Subcategory: event, Sort order: 1081
    case wrappedPresent = "🎁" // Category: activities, Subcategory: event, Sort order: 1082
    case birthdayCake = "🎂" // Category: foodDrink, Subcategory: food-sweet, Sort order: 811
    case jackolantern = "🎃" // Category: activities, Subcategory: event, Sort order: 1065
    case christmasTree = "🎄" // Category: activities, Subcategory: event, Sort order: 1066
    case fatherChristmas = "🎅" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 371
    case fireworks = "🎆" // Category: activities, Subcategory: event, Sort order: 1067
    case fireworkSparkler = "🎇" // Category: activities, Subcategory: event, Sort order: 1068
    case balloon = "🎈" // Category: activities, Subcategory: event, Sort order: 1071
    case partyPopper = "🎉" // Category: activities, Subcategory: event, Sort order: 1072
    case confettiBall = "🎊" // Category: activities, Subcategory: event, Sort order: 1073
    case tanabataTree = "🎋" // Category: activities, Subcategory: event, Sort order: 1074
    case crossedFlags = "🎌" // Category: flags, Subcategory: flag, Sort order: 1637
    case pineDecoration = "🎍" // Category: activities, Subcategory: event, Sort order: 1075
    case japaneseDolls = "🎎" // Category: activities, Subcategory: event, Sort order: 1076
    case carpStreamer = "🎏" // Category: activities, Subcategory: event, Sort order: 1077
    case windChime = "🎐" // Category: activities, Subcategory: event, Sort order: 1078
    case moonViewingCeremony = "🎑" // Category: activities, Subcategory: event, Sort order: 1079
    case schoolSatchel = "🎒" // Category: objects, Subcategory: clothing, Sort order: 1175
    case graduationCap = "🎓" // Category: objects, Subcategory: clothing, Sort order: 1189
    case militaryMedal = "🎖️" // Category: activities, Subcategory: award-medal, Sort order: 1086
    case reminderRibbon = "🎗️" // Category: activities, Subcategory: event, Sort order: 1083
    case studioMicrophone = "🎙️" // Category: objects, Subcategory: music, Sort order: 1209
    case levelSlider = "🎚️" // Category: objects, Subcategory: music, Sort order: 1210
    case controlKnobs = "🎛️" // Category: objects, Subcategory: music, Sort order: 1211
    case filmFrames = "🎞️" // Category: objects, Subcategory: light & video, Sort order: 1247
    case admissionTickets = "🎟️" // Category: activities, Subcategory: event, Sort order: 1084
    case carouselHorse = "🎠" // Category: travelPlaces, Subcategory: place-other, Sort order: 907
    case ferrisWheel = "🎡" // Category: travelPlaces, Subcategory: place-other, Sort order: 909
    case rollerCoaster = "🎢" // Category: travelPlaces, Subcategory: place-other, Sort order: 910
    case fishingPoleAndFish = "🎣" // Category: activities, Subcategory: sport, Sort order: 1113
    case microphone = "🎤" // Category: objects, Subcategory: music, Sort order: 1212
    case movieCamera = "🎥" // Category: objects, Subcategory: light & video, Sort order: 1246
    case cinema = "🎦" // Category: symbols, Subcategory: av-symbol, Sort order: 1503
    case headphone = "🎧" // Category: objects, Subcategory: music, Sort order: 1213
    case artistPalette = "🎨" // Category: activities, Subcategory: arts & crafts, Sort order: 1145
    case topHat = "🎩" // Category: objects, Subcategory: clothing, Sort order: 1188
    case circusTent = "🎪" // Category: travelPlaces, Subcategory: place-other, Sort order: 912
    case ticket = "🎫" // Category: activities, Subcategory: event, Sort order: 1085
    case clapperBoard = "🎬" // Category: objects, Subcategory: light & video, Sort order: 1249
    case performingArts = "🎭" // Category: activities, Subcategory: arts & crafts, Sort order: 1143
    case videoGame = "🎮" // Category: activities, Subcategory: game, Sort order: 1126
    case directHit = "🎯" // Category: activities, Subcategory: game, Sort order: 1119
    case slotMachine = "🎰" // Category: activities, Subcategory: game, Sort order: 1128
    case billiards = "🎱" // Category: activities, Subcategory: game, Sort order: 1123
    case gameDie = "🎲" // Category: activities, Subcategory: game, Sort order: 1129
    case bowling = "🎳" // Category: activities, Subcategory: sport, Sort order: 1101
    case flowerPlayingCards = "🎴" // Category: activities, Subcategory: game, Sort order: 1142
    case musicalNote = "🎵" // Category: objects, Subcategory: music, Sort order: 1207
    case multipleMusicalNotes = "🎶" // Category: objects, Subcategory: music, Sort order: 1208
    case saxophone = "🎷" // Category: objects, Subcategory: musical-instrument, Sort order: 1215
    case guitar = "🎸" // Category: objects, Subcategory: musical-instrument, Sort order: 1217
    case musicalKeyboard = "🎹" // Category: objects, Subcategory: musical-instrument, Sort order: 1218
    case trumpet = "🎺" // Category: objects, Subcategory: musical-instrument, Sort order: 1219
    case violin = "🎻" // Category: objects, Subcategory: musical-instrument, Sort order: 1220
    case musicalScore = "🎼" // Category: objects, Subcategory: music, Sort order: 1206
    case runningShirtWithSash = "🎽" // Category: activities, Subcategory: sport, Sort order: 1115
    case tennisRacquetAndBall = "🎾" // Category: activities, Subcategory: sport, Sort order: 1099
    case skiAndSkiBoot = "🎿" // Category: activities, Subcategory: sport, Sort order: 1116
    case basketballAndHoop = "🏀" // Category: activities, Subcategory: sport, Sort order: 1095
    case chequeredFlag = "🏁" // Category: flags, Subcategory: flag, Sort order: 1635
    case snowboarder = "🏂" // Category: peopleBody, Subcategory: person-sport, Sort order: 462
    case womanRunning = "🏃‍♀️" // Category: peopleBody, Subcategory: person-activity, Sort order: 443
    case womanRunningFacingRight = "🏃‍♀️‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 445
    case manRunning = "🏃‍♂️" // Category: peopleBody, Subcategory: person-activity, Sort order: 442
    case manRunningFacingRight = "🏃‍♂️‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 446
    case personRunningFacingRight = "🏃‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 444
    case runner = "🏃" // Category: peopleBody, Subcategory: person-activity, Sort order: 441
    case womanSurfing = "🏄‍♀️" // Category: peopleBody, Subcategory: person-sport, Sort order: 468
    case manSurfing = "🏄‍♂️" // Category: peopleBody, Subcategory: person-sport, Sort order: 467
    case surfer = "🏄" // Category: peopleBody, Subcategory: person-sport, Sort order: 466
    case sportsMedal = "🏅" // Category: activities, Subcategory: award-medal, Sort order: 1088
    case trophy = "🏆" // Category: activities, Subcategory: award-medal, Sort order: 1087
    case horseRacing = "🏇" // Category: peopleBody, Subcategory: person-sport, Sort order: 460
    case americanFootball = "🏈" // Category: activities, Subcategory: sport, Sort order: 1097
    case rugbyFootball = "🏉" // Category: activities, Subcategory: sport, Sort order: 1098
    case womanSwimming = "🏊‍♀️" // Category: peopleBody, Subcategory: person-sport, Sort order: 474
    case manSwimming = "🏊‍♂️" // Category: peopleBody, Subcategory: person-sport, Sort order: 473
    case swimmer = "🏊" // Category: peopleBody, Subcategory: person-sport, Sort order: 472
    case womanLiftingWeights = "🏋️‍♀️" // Category: peopleBody, Subcategory: person-sport, Sort order: 480
    case manLiftingWeights = "🏋️‍♂️" // Category: peopleBody, Subcategory: person-sport, Sort order: 479
    case personLiftingWeights = "🏋️" // Category: peopleBody, Subcategory: person-sport, Sort order: 478
    case womanGolfing = "🏌️‍♀️" // Category: peopleBody, Subcategory: person-sport, Sort order: 465
    case manGolfing = "🏌️‍♂️" // Category: peopleBody, Subcategory: person-sport, Sort order: 464
    case personGolfing = "🏌️" // Category: peopleBody, Subcategory: person-sport, Sort order: 463
    case motorcycle = "🏍️" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 943
    case racingCar = "🏎️" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 942
    case cricketBatAndBall = "🏏" // Category: activities, Subcategory: sport, Sort order: 1102
    case volleyball = "🏐" // Category: activities, Subcategory: sport, Sort order: 1096
    case fieldHockeyStickAndBall = "🏑" // Category: activities, Subcategory: sport, Sort order: 1103
    case iceHockeyStickAndPuck = "🏒" // Category: activities, Subcategory: sport, Sort order: 1104
    case tableTennisPaddleAndBall = "🏓" // Category: activities, Subcategory: sport, Sort order: 1106
    case snowcappedMountain = "🏔️" // Category: travelPlaces, Subcategory: place-geographic, Sort order: 854
    case camping = "🏕️" // Category: travelPlaces, Subcategory: place-geographic, Sort order: 858
    case beachWithUmbrella = "🏖️" // Category: travelPlaces, Subcategory: place-geographic, Sort order: 859
    case buildingConstruction = "🏗️" // Category: travelPlaces, Subcategory: place-building, Sort order: 865
    case houses = "🏘️" // Category: travelPlaces, Subcategory: place-building, Sort order: 870
    case cityscape = "🏙️" // Category: travelPlaces, Subcategory: place-other, Sort order: 900
    case derelictHouse = "🏚️" // Category: travelPlaces, Subcategory: place-building, Sort order: 871
    case classicalBuilding = "🏛️" // Category: travelPlaces, Subcategory: place-building, Sort order: 864
    case desert = "🏜️" // Category: travelPlaces, Subcategory: place-geographic, Sort order: 860
    case desertIsland = "🏝️" // Category: travelPlaces, Subcategory: place-geographic, Sort order: 861
    case nationalPark = "🏞️" // Category: travelPlaces, Subcategory: place-geographic, Sort order: 862
    case stadium = "🏟️" // Category: travelPlaces, Subcategory: place-building, Sort order: 863
    case houseBuilding = "🏠" // Category: travelPlaces, Subcategory: place-building, Sort order: 872
    case houseWithGarden = "🏡" // Category: travelPlaces, Subcategory: place-building, Sort order: 873
    case officeBuilding = "🏢" // Category: travelPlaces, Subcategory: place-building, Sort order: 874
    case japanesePostOffice = "🏣" // Category: travelPlaces, Subcategory: place-building, Sort order: 875
    case europeanPostOffice = "🏤" // Category: travelPlaces, Subcategory: place-building, Sort order: 876
    case hospital = "🏥" // Category: travelPlaces, Subcategory: place-building, Sort order: 877
    case bank = "🏦" // Category: travelPlaces, Subcategory: place-building, Sort order: 878
    case automatedTellerMachine = "🏧" // Category: symbols, Subcategory: transport-sign, Sort order: 1412
    case hotel = "🏨" // Category: travelPlaces, Subcategory: place-building, Sort order: 879
    case loveHotel = "🏩" // Category: travelPlaces, Subcategory: place-building, Sort order: 880
    case convenienceStore = "🏪" // Category: travelPlaces, Subcategory: place-building, Sort order: 881
    case school = "🏫" // Category: travelPlaces, Subcategory: place-building, Sort order: 882
    case departmentStore = "🏬" // Category: travelPlaces, Subcategory: place-building, Sort order: 883
    case factory = "🏭" // Category: travelPlaces, Subcategory: place-building, Sort order: 884
    case izakayaLantern = "🏮" // Category: objects, Subcategory: light & video, Sort order: 1260
    case japaneseCastle = "🏯" // Category: travelPlaces, Subcategory: place-building, Sort order: 885
    case europeanCastle = "🏰" // Category: travelPlaces, Subcategory: place-building, Sort order: 886
    case rainbowFlag = "🏳️‍🌈" // Category: flags, Subcategory: flag, Sort order: 1640
    case transgenderFlag = "🏳️‍⚧️" // Category: flags, Subcategory: flag, Sort order: 1641
    case whiteFlag = "🏳️" // Category: flags, Subcategory: flag, Sort order: 1639
    case pirateFlag = "🏴‍☠️" // Category: flags, Subcategory: flag, Sort order: 1642
    case englandFlag = "🏴󠁧󠁢󠁥󠁮󠁧󠁿" // Category: flags, Subcategory: subdivision-flag, Sort order: 1901
    case scotlandFlag = "🏴󠁧󠁢󠁳󠁣󠁴󠁿" // Category: flags, Subcategory: subdivision-flag, Sort order: 1902
    case walesFlag = "🏴󠁧󠁢󠁷󠁬󠁳󠁿" // Category: flags, Subcategory: subdivision-flag, Sort order: 1903
    case wavingBlackFlag = "🏴" // Category: flags, Subcategory: flag, Sort order: 1638
    case rosette = "🏵️" // Category: animalsNature, Subcategory: plant-flower, Sort order: 688
    case label = "🏷️" // Category: objects, Subcategory: book-paper, Sort order: 1278
    case badmintonRacquetAndShuttlecock = "🏸" // Category: activities, Subcategory: sport, Sort order: 1107
    case bowAndArrow = "🏹" // Category: objects, Subcategory: tool, Sort order: 1347
    case amphora = "🏺" // Category: foodDrink, Subcategory: dishware, Sort order: 846
    case emojiModifierFitzpatrickType12 = "🏻" // Category: component, Subcategory: skin-tone, Sort order: 554
    case emojiModifierFitzpatrickType3 = "🏼" // Category: component, Subcategory: skin-tone, Sort order: 555
    case emojiModifierFitzpatrickType4 = "🏽" // Category: component, Subcategory: skin-tone, Sort order: 556
    case emojiModifierFitzpatrickType5 = "🏾" // Category: component, Subcategory: skin-tone, Sort order: 557
    case emojiModifierFitzpatrickType6 = "🏿" // Category: component, Subcategory: skin-tone, Sort order: 558
    case rat = "🐀" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 607
    case mouse = "🐁" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 606
    case ox = "🐂" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 587
    case waterBuffalo = "🐃" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 588
    case cow = "🐄" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 589
    case tiger = "🐅" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 576
    case leopard = "🐆" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 577
    case rabbit = "🐇" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 610
    case blackCat = "🐈‍⬛" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 573
    case cat = "🐈" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 572
    case dragon = "🐉" // Category: animalsNature, Subcategory: animal-reptile, Sort order: 653
    case crocodile = "🐊" // Category: animalsNature, Subcategory: animal-reptile, Sort order: 648
    case whale = "🐋" // Category: animalsNature, Subcategory: animal-marine, Sort order: 657
    case snail = "🐌" // Category: animalsNature, Subcategory: animal-bug, Sort order: 668
    case snake = "🐍" // Category: animalsNature, Subcategory: animal-reptile, Sort order: 651
    case horse = "🐎" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 581
    case ram = "🐏" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 594
    case goat = "🐐" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 596
    case sheep = "🐑" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 595
    case monkey = "🐒" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 560
    case rooster = "🐓" // Category: animalsNature, Subcategory: animal-bird, Sort order: 627
    case chicken = "🐔" // Category: animalsNature, Subcategory: animal-bird, Sort order: 626
    case serviceDog = "🐕‍🦺" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 566
    case dog = "🐕" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 564
    case pig = "🐖" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 591
    case boar = "🐗" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 592
    case elephant = "🐘" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 601
    case octopus = "🐙" // Category: animalsNature, Subcategory: animal-marine, Sort order: 664
    case spiralShell = "🐚" // Category: animalsNature, Subcategory: animal-marine, Sort order: 665
    case bug = "🐛" // Category: animalsNature, Subcategory: animal-bug, Sort order: 670
    case ant = "🐜" // Category: animalsNature, Subcategory: animal-bug, Sort order: 671
    case honeybee = "🐝" // Category: animalsNature, Subcategory: animal-bug, Sort order: 672
    case ladyBeetle = "🐞" // Category: animalsNature, Subcategory: animal-bug, Sort order: 674
    case fish = "🐟" // Category: animalsNature, Subcategory: animal-marine, Sort order: 660
    case tropicalFish = "🐠" // Category: animalsNature, Subcategory: animal-marine, Sort order: 661
    case blowfish = "🐡" // Category: animalsNature, Subcategory: animal-marine, Sort order: 662
    case turtle = "🐢" // Category: animalsNature, Subcategory: animal-reptile, Sort order: 649
    case hatchingChick = "🐣" // Category: animalsNature, Subcategory: animal-bird, Sort order: 628
    case babyChick = "🐤" // Category: animalsNature, Subcategory: animal-bird, Sort order: 629
    case frontfacingBabyChick = "🐥" // Category: animalsNature, Subcategory: animal-bird, Sort order: 630
    case phoenix = "🐦‍🔥" // Category: animalsNature, Subcategory: animal-bird, Sort order: 646
    case blackBird = "🐦‍⬛" // Category: animalsNature, Subcategory: animal-bird, Sort order: 644
    case bird = "🐦" // Category: animalsNature, Subcategory: animal-bird, Sort order: 631
    case penguin = "🐧" // Category: animalsNature, Subcategory: animal-bird, Sort order: 632
    case koala = "🐨" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 617
    case poodle = "🐩" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 567
    case dromedaryCamel = "🐪" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 597
    case bactrianCamel = "🐫" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 598
    case dolphin = "🐬" // Category: animalsNature, Subcategory: animal-marine, Sort order: 658
    case mouseFace = "🐭" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 605
    case cowFace = "🐮" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 586
    case tigerFace = "🐯" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 575
    case rabbitFace = "🐰" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 609
    case catFace = "🐱" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 571
    case dragonFace = "🐲" // Category: animalsNature, Subcategory: animal-reptile, Sort order: 652
    case spoutingWhale = "🐳" // Category: animalsNature, Subcategory: animal-marine, Sort order: 656
    case horseFace = "🐴" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 578
    case monkeyFace = "🐵" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 559
    case dogFace = "🐶" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 563
    case pigFace = "🐷" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 590
    case frogFace = "🐸" // Category: animalsNature, Subcategory: animal-amphibian, Sort order: 647
    case hamsterFace = "🐹" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 608
    case wolfFace = "🐺" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 568
    case polarBear = "🐻‍❄️" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 616
    case bearFace = "🐻" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 615
    case pandaFace = "🐼" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 618
    case pigNose = "🐽" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 593
    case pawPrints = "🐾" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 624
    case chipmunk = "🐿️" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 611
    case eyes = "👀" // Category: peopleBody, Subcategory: body-parts, Sort order: 225
    case eyeInSpeechBubble = "👁️‍🗨️" // Category: smileysEmotion, Subcategory: emotion, Sort order: 164
    case eye = "👁️" // Category: peopleBody, Subcategory: body-parts, Sort order: 226
    case ear = "👂" // Category: peopleBody, Subcategory: body-parts, Sort order: 217
    case nose = "👃" // Category: peopleBody, Subcategory: body-parts, Sort order: 219
    case mouth = "👄" // Category: peopleBody, Subcategory: body-parts, Sort order: 228
    case tongue = "👅" // Category: peopleBody, Subcategory: body-parts, Sort order: 227
    case whiteUpPointingBackhandIndex = "👆" // Category: peopleBody, Subcategory: hand-single-finger, Sort order: 191
    case whiteDownPointingBackhandIndex = "👇" // Category: peopleBody, Subcategory: hand-single-finger, Sort order: 193
    case whiteLeftPointingBackhandIndex = "👈" // Category: peopleBody, Subcategory: hand-single-finger, Sort order: 189
    case whiteRightPointingBackhandIndex = "👉" // Category: peopleBody, Subcategory: hand-single-finger, Sort order: 190
    case fistedHandSign = "👊" // Category: peopleBody, Subcategory: hand-fingers-closed, Sort order: 199
    case wavingHandSign = "👋" // Category: peopleBody, Subcategory: hand-fingers-open, Sort order: 169
    case okHandSign = "👌" // Category: peopleBody, Subcategory: hand-fingers-partial, Sort order: 180
    case thumbsUpSign = "👍" // Category: peopleBody, Subcategory: hand-fingers-closed, Sort order: 196
    case thumbsDownSign = "👎" // Category: peopleBody, Subcategory: hand-fingers-closed, Sort order: 197
    case clappingHandsSign = "👏" // Category: peopleBody, Subcategory: hands, Sort order: 202
    case openHandsSign = "👐" // Category: peopleBody, Subcategory: hands, Sort order: 205
    case crown = "👑" // Category: objects, Subcategory: clothing, Sort order: 1186
    case womansHat = "👒" // Category: objects, Subcategory: clothing, Sort order: 1187
    case eyeglasses = "👓" // Category: objects, Subcategory: clothing, Sort order: 1150
    case necktie = "👔" // Category: objects, Subcategory: clothing, Sort order: 1155
    case tshirt = "👕" // Category: objects, Subcategory: clothing, Sort order: 1156
    case jeans = "👖" // Category: objects, Subcategory: clothing, Sort order: 1157
    case dress = "👗" // Category: objects, Subcategory: clothing, Sort order: 1162
    case kimono = "👘" // Category: objects, Subcategory: clothing, Sort order: 1163
    case bikini = "👙" // Category: objects, Subcategory: clothing, Sort order: 1168
    case womansClothes = "👚" // Category: objects, Subcategory: clothing, Sort order: 1169
    case purse = "👛" // Category: objects, Subcategory: clothing, Sort order: 1171
    case handbag = "👜" // Category: objects, Subcategory: clothing, Sort order: 1172
    case pouch = "👝" // Category: objects, Subcategory: clothing, Sort order: 1173
    case mansShoe = "👞" // Category: objects, Subcategory: clothing, Sort order: 1177
    case athleticShoe = "👟" // Category: objects, Subcategory: clothing, Sort order: 1178
    case highheeledShoe = "👠" // Category: objects, Subcategory: clothing, Sort order: 1181
    case womansSandal = "👡" // Category: objects, Subcategory: clothing, Sort order: 1182
    case womansBoots = "👢" // Category: objects, Subcategory: clothing, Sort order: 1184
    case footprints = "👣" // Category: peopleBody, Subcategory: person-symbol, Sort order: 553
    case bustInSilhouette = "👤" // Category: peopleBody, Subcategory: person-symbol, Sort order: 545
    case bustsInSilhouette = "👥" // Category: peopleBody, Subcategory: person-symbol, Sort order: 546
    case boy = "👦" // Category: peopleBody, Subcategory: person, Sort order: 232
    case girl = "👧" // Category: peopleBody, Subcategory: person, Sort order: 233
    case manFarmer = "👨‍🌾" // Category: peopleBody, Subcategory: person-role, Sort order: 301
    case manCook = "👨‍🍳" // Category: peopleBody, Subcategory: person-role, Sort order: 304
    case manFeedingBaby = "👨‍🍼" // Category: peopleBody, Subcategory: person-role, Sort order: 368
    case manStudent = "👨‍🎓" // Category: peopleBody, Subcategory: person-role, Sort order: 292
    case manSinger = "👨‍🎤" // Category: peopleBody, Subcategory: person-role, Sort order: 322
    case manArtist = "👨‍🎨" // Category: peopleBody, Subcategory: person-role, Sort order: 325
    case manTeacher = "👨‍🏫" // Category: peopleBody, Subcategory: person-role, Sort order: 295
    case manFactoryWorker = "👨‍🏭" // Category: peopleBody, Subcategory: person-role, Sort order: 310
    case familyManBoyBoy = "👨‍👦‍👦" // Category: peopleBody, Subcategory: family, Sort order: 535
    case familyManBoy = "👨‍👦" // Category: peopleBody, Subcategory: family, Sort order: 534
    case familyManGirlBoy = "👨‍👧‍👦" // Category: peopleBody, Subcategory: family, Sort order: 537
    case familyManGirlGirl = "👨‍👧‍👧" // Category: peopleBody, Subcategory: family, Sort order: 538
    case familyManGirl = "👨‍👧" // Category: peopleBody, Subcategory: family, Sort order: 536
    case familyManManBoy = "👨‍👨‍👦" // Category: peopleBody, Subcategory: family, Sort order: 524
    case familyManManBoyBoy = "👨‍👨‍👦‍👦" // Category: peopleBody, Subcategory: family, Sort order: 527
    case familyManManGirl = "👨‍👨‍👧" // Category: peopleBody, Subcategory: family, Sort order: 525
    case familyManManGirlBoy = "👨‍👨‍👧‍👦" // Category: peopleBody, Subcategory: family, Sort order: 526
    case familyManManGirlGirl = "👨‍👨‍👧‍👧" // Category: peopleBody, Subcategory: family, Sort order: 528
    case familyManWomanBoy = "👨‍👩‍👦" // Category: peopleBody, Subcategory: family, Sort order: 519
    case familyManWomanBoyBoy = "👨‍👩‍👦‍👦" // Category: peopleBody, Subcategory: family, Sort order: 522
    case familyManWomanGirl = "👨‍👩‍👧" // Category: peopleBody, Subcategory: family, Sort order: 520
    case familyManWomanGirlBoy = "👨‍👩‍👧‍👦" // Category: peopleBody, Subcategory: family, Sort order: 521
    case familyManWomanGirlGirl = "👨‍👩‍👧‍👧" // Category: peopleBody, Subcategory: family, Sort order: 523
    case manTechnologist = "👨‍💻" // Category: peopleBody, Subcategory: person-role, Sort order: 319
    case manOfficeWorker = "👨‍💼" // Category: peopleBody, Subcategory: person-role, Sort order: 313
    case manMechanic = "👨‍🔧" // Category: peopleBody, Subcategory: person-role, Sort order: 307
    case manScientist = "👨‍🔬" // Category: peopleBody, Subcategory: person-role, Sort order: 316
    case manAstronaut = "👨‍🚀" // Category: peopleBody, Subcategory: person-role, Sort order: 331
    case manFirefighter = "👨‍🚒" // Category: peopleBody, Subcategory: person-role, Sort order: 334
    case manWithWhiteCaneFacingRight = "👨‍🦯‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 426
    case manWithWhiteCane = "👨‍🦯" // Category: peopleBody, Subcategory: person-activity, Sort order: 425
    case manRedHair = "👨‍🦰" // Category: peopleBody, Subcategory: person, Sort order: 240
    case manCurlyHair = "👨‍🦱" // Category: peopleBody, Subcategory: person, Sort order: 241
    case manBald = "👨‍🦲" // Category: peopleBody, Subcategory: person, Sort order: 243
    case manWhiteHair = "👨‍🦳" // Category: peopleBody, Subcategory: person, Sort order: 242
    case manInMotorizedWheelchairFacingRight = "👨‍🦼‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 432
    case manInMotorizedWheelchair = "👨‍🦼" // Category: peopleBody, Subcategory: person-activity, Sort order: 431
    case manInManualWheelchairFacingRight = "👨‍🦽‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 438
    case manInManualWheelchair = "👨‍🦽" // Category: peopleBody, Subcategory: person-activity, Sort order: 437
    case manHealthWorker = "👨‍⚕️" // Category: peopleBody, Subcategory: person-role, Sort order: 289
    case manJudge = "👨‍⚖️" // Category: peopleBody, Subcategory: person-role, Sort order: 298
    case manPilot = "👨‍✈️" // Category: peopleBody, Subcategory: person-role, Sort order: 328
    case coupleWithHeartManMan = "👨‍❤️‍👨" // Category: peopleBody, Subcategory: family, Sort order: 517
    case kissManMan = "👨‍❤️‍💋‍👨" // Category: peopleBody, Subcategory: family, Sort order: 513
    case man = "👨" // Category: peopleBody, Subcategory: person, Sort order: 236
    case womanFarmer = "👩‍🌾" // Category: peopleBody, Subcategory: person-role, Sort order: 302
    case womanCook = "👩‍🍳" // Category: peopleBody, Subcategory: person-role, Sort order: 305
    case womanFeedingBaby = "👩‍🍼" // Category: peopleBody, Subcategory: person-role, Sort order: 367
    case womanStudent = "👩‍🎓" // Category: peopleBody, Subcategory: person-role, Sort order: 293
    case womanSinger = "👩‍🎤" // Category: peopleBody, Subcategory: person-role, Sort order: 323
    case womanArtist = "👩‍🎨" // Category: peopleBody, Subcategory: person-role, Sort order: 326
    case womanTeacher = "👩‍🏫" // Category: peopleBody, Subcategory: person-role, Sort order: 296
    case womanFactoryWorker = "👩‍🏭" // Category: peopleBody, Subcategory: person-role, Sort order: 311
    case familyWomanBoyBoy = "👩‍👦‍👦" // Category: peopleBody, Subcategory: family, Sort order: 540
    case familyWomanBoy = "👩‍👦" // Category: peopleBody, Subcategory: family, Sort order: 539
    case familyWomanGirlBoy = "👩‍👧‍👦" // Category: peopleBody, Subcategory: family, Sort order: 542
    case familyWomanGirlGirl = "👩‍👧‍👧" // Category: peopleBody, Subcategory: family, Sort order: 543
    case familyWomanGirl = "👩‍👧" // Category: peopleBody, Subcategory: family, Sort order: 541
    case familyWomanWomanBoy = "👩‍👩‍👦" // Category: peopleBody, Subcategory: family, Sort order: 529
    case familyWomanWomanBoyBoy = "👩‍👩‍👦‍👦" // Category: peopleBody, Subcategory: family, Sort order: 532
    case familyWomanWomanGirl = "👩‍👩‍👧" // Category: peopleBody, Subcategory: family, Sort order: 530
    case familyWomanWomanGirlBoy = "👩‍👩‍👧‍👦" // Category: peopleBody, Subcategory: family, Sort order: 531
    case familyWomanWomanGirlGirl = "👩‍👩‍👧‍👧" // Category: peopleBody, Subcategory: family, Sort order: 533
    case womanTechnologist = "👩‍💻" // Category: peopleBody, Subcategory: person-role, Sort order: 320
    case womanOfficeWorker = "👩‍💼" // Category: peopleBody, Subcategory: person-role, Sort order: 314
    case womanMechanic = "👩‍🔧" // Category: peopleBody, Subcategory: person-role, Sort order: 308
    case womanScientist = "👩‍🔬" // Category: peopleBody, Subcategory: person-role, Sort order: 317
    case womanAstronaut = "👩‍🚀" // Category: peopleBody, Subcategory: person-role, Sort order: 332
    case womanFirefighter = "👩‍🚒" // Category: peopleBody, Subcategory: person-role, Sort order: 335
    case womanWithWhiteCaneFacingRight = "👩‍🦯‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 428
    case womanWithWhiteCane = "👩‍🦯" // Category: peopleBody, Subcategory: person-activity, Sort order: 427
    case womanRedHair = "👩‍🦰" // Category: peopleBody, Subcategory: person, Sort order: 245
    case womanCurlyHair = "👩‍🦱" // Category: peopleBody, Subcategory: person, Sort order: 247
    case womanBald = "👩‍🦲" // Category: peopleBody, Subcategory: person, Sort order: 251
    case womanWhiteHair = "👩‍🦳" // Category: peopleBody, Subcategory: person, Sort order: 249
    case womanInMotorizedWheelchairFacingRight = "👩‍🦼‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 434
    case womanInMotorizedWheelchair = "👩‍🦼" // Category: peopleBody, Subcategory: person-activity, Sort order: 433
    case womanInManualWheelchairFacingRight = "👩‍🦽‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 440
    case womanInManualWheelchair = "👩‍🦽" // Category: peopleBody, Subcategory: person-activity, Sort order: 439
    case womanHealthWorker = "👩‍⚕️" // Category: peopleBody, Subcategory: person-role, Sort order: 290
    case womanJudge = "👩‍⚖️" // Category: peopleBody, Subcategory: person-role, Sort order: 299
    case womanPilot = "👩‍✈️" // Category: peopleBody, Subcategory: person-role, Sort order: 329
    case coupleWithHeartWomanMan = "👩‍❤️‍👨" // Category: peopleBody, Subcategory: family, Sort order: 516
    case coupleWithHeartWomanWoman = "👩‍❤️‍👩" // Category: peopleBody, Subcategory: family, Sort order: 518
    case kissWomanMan = "👩‍❤️‍💋‍👨" // Category: peopleBody, Subcategory: family, Sort order: 512
    case kissWomanWoman = "👩‍❤️‍💋‍👩" // Category: peopleBody, Subcategory: family, Sort order: 514
    case woman = "👩" // Category: peopleBody, Subcategory: person, Sort order: 244
    case family = "👪" // Category: peopleBody, Subcategory: person-symbol, Sort order: 548
    case manAndWomanHoldingHands = "👫" // Category: peopleBody, Subcategory: family, Sort order: 509
    case twoMenHoldingHands = "👬" // Category: peopleBody, Subcategory: family, Sort order: 510
    case twoWomenHoldingHands = "👭" // Category: peopleBody, Subcategory: family, Sort order: 508
    case womanPoliceOfficer = "👮‍♀️" // Category: peopleBody, Subcategory: person-role, Sort order: 338
    case manPoliceOfficer = "👮‍♂️" // Category: peopleBody, Subcategory: person-role, Sort order: 337
    case policeOfficer = "👮" // Category: peopleBody, Subcategory: person-role, Sort order: 336
    case womenWithBunnyEars = "👯‍♀️" // Category: peopleBody, Subcategory: person-activity, Sort order: 452
    case menWithBunnyEars = "👯‍♂️" // Category: peopleBody, Subcategory: person-activity, Sort order: 451
    case womanWithBunnyEars = "👯" // Category: peopleBody, Subcategory: person-activity, Sort order: 450
    case womanWithVeil = "👰‍♀️" // Category: peopleBody, Subcategory: person-role, Sort order: 362
    case manWithVeil = "👰‍♂️" // Category: peopleBody, Subcategory: person-role, Sort order: 361
    case brideWithVeil = "👰" // Category: peopleBody, Subcategory: person-role, Sort order: 360
    case womanBlondHair = "👱‍♀️" // Category: peopleBody, Subcategory: person, Sort order: 253
    case manBlondHair = "👱‍♂️" // Category: peopleBody, Subcategory: person, Sort order: 254
    case personWithBlondHair = "👱" // Category: peopleBody, Subcategory: person, Sort order: 235
    case manWithGuaPiMao = "👲" // Category: peopleBody, Subcategory: person-role, Sort order: 355
    case womanWearingTurban = "👳‍♀️" // Category: peopleBody, Subcategory: person-role, Sort order: 354
    case manWearingTurban = "👳‍♂️" // Category: peopleBody, Subcategory: person-role, Sort order: 353
    case manWithTurban = "👳" // Category: peopleBody, Subcategory: person-role, Sort order: 352
    case olderMan = "👴" // Category: peopleBody, Subcategory: person, Sort order: 256
    case olderWoman = "👵" // Category: peopleBody, Subcategory: person, Sort order: 257
    case baby = "👶" // Category: peopleBody, Subcategory: person, Sort order: 230
    case womanConstructionWorker = "👷‍♀️" // Category: peopleBody, Subcategory: person-role, Sort order: 348
    case manConstructionWorker = "👷‍♂️" // Category: peopleBody, Subcategory: person-role, Sort order: 347
    case constructionWorker = "👷" // Category: peopleBody, Subcategory: person-role, Sort order: 346
    case princess = "👸" // Category: peopleBody, Subcategory: person-role, Sort order: 351
    case japaneseOgre = "👹" // Category: smileysEmotion, Subcategory: face-costume, Sort order: 112
    case japaneseGoblin = "👺" // Category: smileysEmotion, Subcategory: face-costume, Sort order: 113
    case ghost = "👻" // Category: smileysEmotion, Subcategory: face-costume, Sort order: 114
    case babyAngel = "👼" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 370
    case extraterrestrialAlien = "👽" // Category: smileysEmotion, Subcategory: face-costume, Sort order: 115
    case alienMonster = "👾" // Category: smileysEmotion, Subcategory: face-costume, Sort order: 116
    case imp = "👿" // Category: smileysEmotion, Subcategory: face-negative, Sort order: 107
    case skull = "💀" // Category: smileysEmotion, Subcategory: face-negative, Sort order: 108
    case womanTippingHand = "💁‍♀️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 272
    case manTippingHand = "💁‍♂️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 271
    case informationDeskPerson = "💁" // Category: peopleBody, Subcategory: person-gesture, Sort order: 270
    case womanGuard = "💂‍♀️" // Category: peopleBody, Subcategory: person-role, Sort order: 344
    case manGuard = "💂‍♂️" // Category: peopleBody, Subcategory: person-role, Sort order: 343
    case guardsman = "💂" // Category: peopleBody, Subcategory: person-role, Sort order: 342
    case dancer = "💃" // Category: peopleBody, Subcategory: person-activity, Sort order: 447
    case lipstick = "💄" // Category: objects, Subcategory: clothing, Sort order: 1194
    case nailPolish = "💅" // Category: peopleBody, Subcategory: hand-prop, Sort order: 210
    case womanGettingMassage = "💆‍♀️" // Category: peopleBody, Subcategory: person-activity, Sort order: 404
    case manGettingMassage = "💆‍♂️" // Category: peopleBody, Subcategory: person-activity, Sort order: 403
    case faceMassage = "💆" // Category: peopleBody, Subcategory: person-activity, Sort order: 402
    case womanGettingHaircut = "💇‍♀️" // Category: peopleBody, Subcategory: person-activity, Sort order: 407
    case manGettingHaircut = "💇‍♂️" // Category: peopleBody, Subcategory: person-activity, Sort order: 406
    case haircut = "💇" // Category: peopleBody, Subcategory: person-activity, Sort order: 405
    case barberPole = "💈" // Category: travelPlaces, Subcategory: place-other, Sort order: 911
    case syringe = "💉" // Category: objects, Subcategory: medical, Sort order: 1371
    case pill = "💊" // Category: objects, Subcategory: medical, Sort order: 1373
    case kissMark = "💋" // Category: smileysEmotion, Subcategory: emotion, Sort order: 155
    case loveLetter = "💌" // Category: smileysEmotion, Subcategory: heart, Sort order: 130
    case ring = "💍" // Category: objects, Subcategory: clothing, Sort order: 1195
    case gemStone = "💎" // Category: objects, Subcategory: clothing, Sort order: 1196
    case kiss = "💏" // Category: peopleBody, Subcategory: family, Sort order: 511
    case bouquet = "💐" // Category: animalsNature, Subcategory: plant-flower, Sort order: 684
    case coupleWithHeart = "💑" // Category: peopleBody, Subcategory: family, Sort order: 515
    case wedding = "💒" // Category: travelPlaces, Subcategory: place-building, Sort order: 887
    case beatingHeart = "💓" // Category: smileysEmotion, Subcategory: heart, Sort order: 135
    case brokenHeart = "💔" // Category: smileysEmotion, Subcategory: heart, Sort order: 140
    case twoHearts = "💕" // Category: smileysEmotion, Subcategory: heart, Sort order: 137
    case sparklingHeart = "💖" // Category: smileysEmotion, Subcategory: heart, Sort order: 133
    case growingHeart = "💗" // Category: smileysEmotion, Subcategory: heart, Sort order: 134
    case heartWithArrow = "💘" // Category: smileysEmotion, Subcategory: heart, Sort order: 131
    case blueHeart = "💙" // Category: smileysEmotion, Subcategory: heart, Sort order: 148
    case greenHeart = "💚" // Category: smileysEmotion, Subcategory: heart, Sort order: 147
    case yellowHeart = "💛" // Category: smileysEmotion, Subcategory: heart, Sort order: 146
    case purpleHeart = "💜" // Category: smileysEmotion, Subcategory: heart, Sort order: 150
    case heartWithRibbon = "💝" // Category: smileysEmotion, Subcategory: heart, Sort order: 132
    case revolvingHearts = "💞" // Category: smileysEmotion, Subcategory: heart, Sort order: 136
    case heartDecoration = "💟" // Category: smileysEmotion, Subcategory: heart, Sort order: 138
    case diamondShapeWithADotInside = "💠" // Category: symbols, Subcategory: geometric, Sort order: 1631
    case electricLightBulb = "💡" // Category: objects, Subcategory: light & video, Sort order: 1258
    case angerSymbol = "💢" // Category: smileysEmotion, Subcategory: emotion, Sort order: 157
    case bomb = "💣" // Category: objects, Subcategory: tool, Sort order: 1345
    case sleepingSymbol = "💤" // Category: smileysEmotion, Subcategory: emotion, Sort order: 168
    case collisionSymbol = "💥" // Category: smileysEmotion, Subcategory: emotion, Sort order: 158
    case splashingSweatSymbol = "💦" // Category: smileysEmotion, Subcategory: emotion, Sort order: 160
    case droplet = "💧" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1063
    case dashSymbol = "💨" // Category: smileysEmotion, Subcategory: emotion, Sort order: 161
    case pileOfPoo = "💩" // Category: smileysEmotion, Subcategory: face-costume, Sort order: 110
    case flexedBiceps = "💪" // Category: peopleBody, Subcategory: body-parts, Sort order: 212
    case dizzySymbol = "💫" // Category: smileysEmotion, Subcategory: emotion, Sort order: 159
    case speechBalloon = "💬" // Category: smileysEmotion, Subcategory: emotion, Sort order: 163
    case thoughtBalloon = "💭" // Category: smileysEmotion, Subcategory: emotion, Sort order: 167
    case whiteFlower = "💮" // Category: animalsNature, Subcategory: plant-flower, Sort order: 686
    case hundredPointsSymbol = "💯" // Category: smileysEmotion, Subcategory: emotion, Sort order: 156
    case moneyBag = "💰" // Category: objects, Subcategory: money, Sort order: 1279
    case currencyExchange = "💱" // Category: symbols, Subcategory: currency, Sort order: 1526
    case heavyDollarSign = "💲" // Category: symbols, Subcategory: currency, Sort order: 1527
    case creditCard = "💳" // Category: objects, Subcategory: money, Sort order: 1286
    case banknoteWithYenSign = "💴" // Category: objects, Subcategory: money, Sort order: 1281
    case banknoteWithDollarSign = "💵" // Category: objects, Subcategory: money, Sort order: 1282
    case banknoteWithEuroSign = "💶" // Category: objects, Subcategory: money, Sort order: 1283
    case banknoteWithPoundSign = "💷" // Category: objects, Subcategory: money, Sort order: 1284
    case moneyWithWings = "💸" // Category: objects, Subcategory: money, Sort order: 1285
    case chartWithUpwardsTrendAndYenSign = "💹" // Category: objects, Subcategory: money, Sort order: 1288
    case seat = "💺" // Category: travelPlaces, Subcategory: transport-air, Sort order: 977
    case personalComputer = "💻" // Category: objects, Subcategory: computer, Sort order: 1235
    case briefcase = "💼" // Category: objects, Subcategory: office, Sort order: 1309
    case minidisc = "💽" // Category: objects, Subcategory: computer, Sort order: 1241
    case floppyDisk = "💾" // Category: objects, Subcategory: computer, Sort order: 1242
    case opticalDisc = "💿" // Category: objects, Subcategory: computer, Sort order: 1243
    case dvd = "📀" // Category: objects, Subcategory: computer, Sort order: 1244
    case fileFolder = "📁" // Category: objects, Subcategory: office, Sort order: 1310
    case openFileFolder = "📂" // Category: objects, Subcategory: office, Sort order: 1311
    case pageWithCurl = "📃" // Category: objects, Subcategory: book-paper, Sort order: 1271
    case pageFacingUp = "📄" // Category: objects, Subcategory: book-paper, Sort order: 1273
    case calendar = "📅" // Category: objects, Subcategory: office, Sort order: 1313
    case tearoffCalendar = "📆" // Category: objects, Subcategory: office, Sort order: 1314
    case cardIndex = "📇" // Category: objects, Subcategory: office, Sort order: 1317
    case chartWithUpwardsTrend = "📈" // Category: objects, Subcategory: office, Sort order: 1318
    case chartWithDownwardsTrend = "📉" // Category: objects, Subcategory: office, Sort order: 1319
    case barChart = "📊" // Category: objects, Subcategory: office, Sort order: 1320
    case clipboard = "📋" // Category: objects, Subcategory: office, Sort order: 1321
    case pushpin = "📌" // Category: objects, Subcategory: office, Sort order: 1322
    case roundPushpin = "📍" // Category: objects, Subcategory: office, Sort order: 1323
    case paperclip = "📎" // Category: objects, Subcategory: office, Sort order: 1324
    case straightRuler = "📏" // Category: objects, Subcategory: office, Sort order: 1326
    case triangularRuler = "📐" // Category: objects, Subcategory: office, Sort order: 1327
    case bookmarkTabs = "📑" // Category: objects, Subcategory: book-paper, Sort order: 1276
    case ledger = "📒" // Category: objects, Subcategory: book-paper, Sort order: 1270
    case notebook = "📓" // Category: objects, Subcategory: book-paper, Sort order: 1269
    case notebookWithDecorativeCover = "📔" // Category: objects, Subcategory: book-paper, Sort order: 1262
    case closedBook = "📕" // Category: objects, Subcategory: book-paper, Sort order: 1263
    case openBook = "📖" // Category: objects, Subcategory: book-paper, Sort order: 1264
    case greenBook = "📗" // Category: objects, Subcategory: book-paper, Sort order: 1265
    case blueBook = "📘" // Category: objects, Subcategory: book-paper, Sort order: 1266
    case orangeBook = "📙" // Category: objects, Subcategory: book-paper, Sort order: 1267
    case books = "📚" // Category: objects, Subcategory: book-paper, Sort order: 1268
    case nameBadge = "📛" // Category: symbols, Subcategory: other-symbol, Sort order: 1532
    case scroll = "📜" // Category: objects, Subcategory: book-paper, Sort order: 1272
    case memo = "📝" // Category: objects, Subcategory: writing, Sort order: 1308
    case telephoneReceiver = "📞" // Category: objects, Subcategory: phone, Sort order: 1229
    case pager = "📟" // Category: objects, Subcategory: phone, Sort order: 1230
    case faxMachine = "📠" // Category: objects, Subcategory: phone, Sort order: 1231
    case satelliteAntenna = "📡" // Category: objects, Subcategory: science, Sort order: 1370
    case publicAddressLoudspeaker = "📢" // Category: objects, Subcategory: sound, Sort order: 1201
    case cheeringMegaphone = "📣" // Category: objects, Subcategory: sound, Sort order: 1202
    case outboxTray = "📤" // Category: objects, Subcategory: mail, Sort order: 1293
    case inboxTray = "📥" // Category: objects, Subcategory: mail, Sort order: 1294
    case package = "📦" // Category: objects, Subcategory: mail, Sort order: 1295
    case emailSymbol = "📧" // Category: objects, Subcategory: mail, Sort order: 1290
    case incomingEnvelope = "📨" // Category: objects, Subcategory: mail, Sort order: 1291
    case envelopeWithDownwardsArrowAbove = "📩" // Category: objects, Subcategory: mail, Sort order: 1292
    case closedMailboxWithLoweredFlag = "📪" // Category: objects, Subcategory: mail, Sort order: 1297
    case closedMailboxWithRaisedFlag = "📫" // Category: objects, Subcategory: mail, Sort order: 1296
    case openMailboxWithRaisedFlag = "📬" // Category: objects, Subcategory: mail, Sort order: 1298
    case openMailboxWithLoweredFlag = "📭" // Category: objects, Subcategory: mail, Sort order: 1299
    case postbox = "📮" // Category: objects, Subcategory: mail, Sort order: 1300
    case postalHorn = "📯" // Category: objects, Subcategory: sound, Sort order: 1203
    case newspaper = "📰" // Category: objects, Subcategory: book-paper, Sort order: 1274
    case mobilePhone = "📱" // Category: objects, Subcategory: phone, Sort order: 1226
    case mobilePhoneWithRightwardsArrowAtLeft = "📲" // Category: objects, Subcategory: phone, Sort order: 1227
    case vibrationMode = "📳" // Category: symbols, Subcategory: av-symbol, Sort order: 1508
    case mobilePhoneOff = "📴" // Category: symbols, Subcategory: av-symbol, Sort order: 1509
    case noMobilePhones = "📵" // Category: symbols, Subcategory: warning, Sort order: 1434
    case antennaWithBars = "📶" // Category: symbols, Subcategory: av-symbol, Sort order: 1506
    case camera = "📷" // Category: objects, Subcategory: light & video, Sort order: 1251
    case cameraWithFlash = "📸" // Category: objects, Subcategory: light & video, Sort order: 1252
    case videoCamera = "📹" // Category: objects, Subcategory: light & video, Sort order: 1253
    case television = "📺" // Category: objects, Subcategory: light & video, Sort order: 1250
    case radio = "📻" // Category: objects, Subcategory: music, Sort order: 1214
    case videocassette = "📼" // Category: objects, Subcategory: light & video, Sort order: 1254
    case filmProjector = "📽️" // Category: objects, Subcategory: light & video, Sort order: 1248
    case prayerBeads = "📿" // Category: objects, Subcategory: clothing, Sort order: 1193
    case twistedRightwardsArrows = "🔀" // Category: symbols, Subcategory: av-symbol, Sort order: 1485
    case clockwiseRightwardsAndLeftwardsOpenCircleArrows = "🔁" // Category: symbols, Subcategory: av-symbol, Sort order: 1486
    case clockwiseRightwardsAndLeftwardsOpenCircleArrowsWithCircledOneOverlay = "🔂" // Category: symbols, Subcategory: av-symbol, Sort order: 1487
    case clockwiseDownwardsAndUpwardsOpenCircleArrows = "🔃" // Category: symbols, Subcategory: arrow, Sort order: 1452
    case anticlockwiseDownwardsAndUpwardsOpenCircleArrows = "🔄" // Category: symbols, Subcategory: arrow, Sort order: 1453
    case lowBrightnessSymbol = "🔅" // Category: symbols, Subcategory: av-symbol, Sort order: 1504
    case highBrightnessSymbol = "🔆" // Category: symbols, Subcategory: av-symbol, Sort order: 1505
    case speakerWithCancellationStroke = "🔇" // Category: objects, Subcategory: sound, Sort order: 1197
    case speaker = "🔈" // Category: objects, Subcategory: sound, Sort order: 1198
    case speakerWithOneSoundWave = "🔉" // Category: objects, Subcategory: sound, Sort order: 1199
    case speakerWithThreeSoundWaves = "🔊" // Category: objects, Subcategory: sound, Sort order: 1200
    case battery = "🔋" // Category: objects, Subcategory: computer, Sort order: 1232
    case electricPlug = "🔌" // Category: objects, Subcategory: computer, Sort order: 1234
    case leftpointingMagnifyingGlass = "🔍" // Category: objects, Subcategory: light & video, Sort order: 1255
    case rightpointingMagnifyingGlass = "🔎" // Category: objects, Subcategory: light & video, Sort order: 1256
    case lockWithInkPen = "🔏" // Category: objects, Subcategory: lock, Sort order: 1334
    case closedLockWithKey = "🔐" // Category: objects, Subcategory: lock, Sort order: 1335
    case key = "🔑" // Category: objects, Subcategory: lock, Sort order: 1336
    case lock = "🔒" // Category: objects, Subcategory: lock, Sort order: 1332
    case openLock = "🔓" // Category: objects, Subcategory: lock, Sort order: 1333
    case bell = "🔔" // Category: objects, Subcategory: sound, Sort order: 1204
    case bellWithCancellationStroke = "🔕" // Category: objects, Subcategory: sound, Sort order: 1205
    case bookmark = "🔖" // Category: objects, Subcategory: book-paper, Sort order: 1277
    case linkSymbol = "🔗" // Category: objects, Subcategory: tool, Sort order: 1357
    case radioButton = "🔘" // Category: symbols, Subcategory: geometric, Sort order: 1632
    case backWithLeftwardsArrowAbove = "🔙" // Category: symbols, Subcategory: arrow, Sort order: 1454
    case endWithLeftwardsArrowAbove = "🔚" // Category: symbols, Subcategory: arrow, Sort order: 1455
    case onWithExclamationMarkWithLeftRightArrowAbove = "🔛" // Category: symbols, Subcategory: arrow, Sort order: 1456
    case soonWithRightwardsArrowAbove = "🔜" // Category: symbols, Subcategory: arrow, Sort order: 1457
    case topWithUpwardsArrowAbove = "🔝" // Category: symbols, Subcategory: arrow, Sort order: 1458
    case noOneUnderEighteenSymbol = "🔞" // Category: symbols, Subcategory: warning, Sort order: 1435
    case keycapTen = "🔟" // Category: symbols, Subcategory: keycap, Sort order: 1561
    case inputSymbolForLatinCapitalLetters = "🔠" // Category: symbols, Subcategory: alphanum, Sort order: 1562
    case inputSymbolForLatinSmallLetters = "🔡" // Category: symbols, Subcategory: alphanum, Sort order: 1563
    case inputSymbolForNumbers = "🔢" // Category: symbols, Subcategory: alphanum, Sort order: 1564
    case inputSymbolForSymbols = "🔣" // Category: symbols, Subcategory: alphanum, Sort order: 1565
    case inputSymbolForLatinLetters = "🔤" // Category: symbols, Subcategory: alphanum, Sort order: 1566
    case fire = "🔥" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1062
    case electricTorch = "🔦" // Category: objects, Subcategory: light & video, Sort order: 1259
    case wrench = "🔧" // Category: objects, Subcategory: tool, Sort order: 1350
    case hammer = "🔨" // Category: objects, Subcategory: tool, Sort order: 1338
    case nutAndBolt = "🔩" // Category: objects, Subcategory: tool, Sort order: 1352
    case hocho = "🔪" // Category: foodDrink, Subcategory: dishware, Sort order: 844
    case pistol = "🔫" // Category: activities, Subcategory: game, Sort order: 1122
    case microscope = "🔬" // Category: objects, Subcategory: science, Sort order: 1368
    case telescope = "🔭" // Category: objects, Subcategory: science, Sort order: 1369
    case crystalBall = "🔮" // Category: activities, Subcategory: game, Sort order: 1124
    case sixPointedStarWithMiddleDot = "🔯" // Category: symbols, Subcategory: religion, Sort order: 1470
    case japaneseSymbolForBeginner = "🔰" // Category: symbols, Subcategory: other-symbol, Sort order: 1533
    case tridentEmblem = "🔱" // Category: symbols, Subcategory: other-symbol, Sort order: 1531
    case blackSquareButton = "🔲" // Category: symbols, Subcategory: geometric, Sort order: 1634
    case whiteSquareButton = "🔳" // Category: symbols, Subcategory: geometric, Sort order: 1633
    case largeRedCircle = "🔴" // Category: symbols, Subcategory: geometric, Sort order: 1601
    case largeBlueCircle = "🔵" // Category: symbols, Subcategory: geometric, Sort order: 1605
    case largeOrangeDiamond = "🔶" // Category: symbols, Subcategory: geometric, Sort order: 1625
    case largeBlueDiamond = "🔷" // Category: symbols, Subcategory: geometric, Sort order: 1626
    case smallOrangeDiamond = "🔸" // Category: symbols, Subcategory: geometric, Sort order: 1627
    case smallBlueDiamond = "🔹" // Category: symbols, Subcategory: geometric, Sort order: 1628
    case uppointingRedTriangle = "🔺" // Category: symbols, Subcategory: geometric, Sort order: 1629
    case downpointingRedTriangle = "🔻" // Category: symbols, Subcategory: geometric, Sort order: 1630
    case uppointingSmallRedTriangle = "🔼" // Category: symbols, Subcategory: av-symbol, Sort order: 1495
    case downpointingSmallRedTriangle = "🔽" // Category: symbols, Subcategory: av-symbol, Sort order: 1497
    case om = "🕉️" // Category: symbols, Subcategory: religion, Sort order: 1461
    case dove = "🕊️" // Category: animalsNature, Subcategory: animal-bird, Sort order: 633
    case kaaba = "🕋" // Category: travelPlaces, Subcategory: place-religious, Sort order: 895
    case mosque = "🕌" // Category: travelPlaces, Subcategory: place-religious, Sort order: 891
    case synagogue = "🕍" // Category: travelPlaces, Subcategory: place-religious, Sort order: 893
    case menorahWithNineBranches = "🕎" // Category: symbols, Subcategory: religion, Sort order: 1469
    case clockFaceOneOclock = "🕐" // Category: travelPlaces, Subcategory: time, Sort order: 996
    case clockFaceTwoOclock = "🕑" // Category: travelPlaces, Subcategory: time, Sort order: 998
    case clockFaceThreeOclock = "🕒" // Category: travelPlaces, Subcategory: time, Sort order: 1000
    case clockFaceFourOclock = "🕓" // Category: travelPlaces, Subcategory: time, Sort order: 1002
    case clockFaceFiveOclock = "🕔" // Category: travelPlaces, Subcategory: time, Sort order: 1004
    case clockFaceSixOclock = "🕕" // Category: travelPlaces, Subcategory: time, Sort order: 1006
    case clockFaceSevenOclock = "🕖" // Category: travelPlaces, Subcategory: time, Sort order: 1008
    case clockFaceEightOclock = "🕗" // Category: travelPlaces, Subcategory: time, Sort order: 1010
    case clockFaceNineOclock = "🕘" // Category: travelPlaces, Subcategory: time, Sort order: 1012
    case clockFaceTenOclock = "🕙" // Category: travelPlaces, Subcategory: time, Sort order: 1014
    case clockFaceElevenOclock = "🕚" // Category: travelPlaces, Subcategory: time, Sort order: 1016
    case clockFaceTwelveOclock = "🕛" // Category: travelPlaces, Subcategory: time, Sort order: 994
    case clockFaceOnethirty = "🕜" // Category: travelPlaces, Subcategory: time, Sort order: 997
    case clockFaceTwothirty = "🕝" // Category: travelPlaces, Subcategory: time, Sort order: 999
    case clockFaceThreethirty = "🕞" // Category: travelPlaces, Subcategory: time, Sort order: 1001
    case clockFaceFourthirty = "🕟" // Category: travelPlaces, Subcategory: time, Sort order: 1003
    case clockFaceFivethirty = "🕠" // Category: travelPlaces, Subcategory: time, Sort order: 1005
    case clockFaceSixthirty = "🕡" // Category: travelPlaces, Subcategory: time, Sort order: 1007
    case clockFaceSeventhirty = "🕢" // Category: travelPlaces, Subcategory: time, Sort order: 1009
    case clockFaceEightthirty = "🕣" // Category: travelPlaces, Subcategory: time, Sort order: 1011
    case clockFaceNinethirty = "🕤" // Category: travelPlaces, Subcategory: time, Sort order: 1013
    case clockFaceTenthirty = "🕥" // Category: travelPlaces, Subcategory: time, Sort order: 1015
    case clockFaceEleventhirty = "🕦" // Category: travelPlaces, Subcategory: time, Sort order: 1017
    case clockFaceTwelvethirty = "🕧" // Category: travelPlaces, Subcategory: time, Sort order: 995
    case candle = "🕯️" // Category: objects, Subcategory: light & video, Sort order: 1257
    case mantelpieceClock = "🕰️" // Category: travelPlaces, Subcategory: time, Sort order: 993
    case hole = "🕳️" // Category: smileysEmotion, Subcategory: emotion, Sort order: 162
    case personInSuitLevitating = "🕴️" // Category: peopleBody, Subcategory: person-activity, Sort order: 449
    case womanDetective = "🕵️‍♀️" // Category: peopleBody, Subcategory: person-role, Sort order: 341
    case manDetective = "🕵️‍♂️" // Category: peopleBody, Subcategory: person-role, Sort order: 340
    case detective = "🕵️" // Category: peopleBody, Subcategory: person-role, Sort order: 339
    case sunglasses = "🕶️" // Category: objects, Subcategory: clothing, Sort order: 1151
    case spider = "🕷️" // Category: animalsNature, Subcategory: animal-bug, Sort order: 677
    case spiderWeb = "🕸️" // Category: animalsNature, Subcategory: animal-bug, Sort order: 678
    case joystick = "🕹️" // Category: activities, Subcategory: game, Sort order: 1127
    case manDancing = "🕺" // Category: peopleBody, Subcategory: person-activity, Sort order: 448
    case linkedPaperclips = "🖇️" // Category: objects, Subcategory: office, Sort order: 1325
    case pen = "🖊️" // Category: objects, Subcategory: writing, Sort order: 1305
    case fountainPen = "🖋️" // Category: objects, Subcategory: writing, Sort order: 1304
    case paintbrush = "🖌️" // Category: objects, Subcategory: writing, Sort order: 1306
    case crayon = "🖍️" // Category: objects, Subcategory: writing, Sort order: 1307
    case handWithFingersSplayed = "🖐️" // Category: peopleBody, Subcategory: hand-fingers-open, Sort order: 171
    case reversedHandWithMiddleFingerExtended = "🖕" // Category: peopleBody, Subcategory: hand-single-finger, Sort order: 192
    case raisedHandWithPartBetweenMiddleAndRingFingers = "🖖" // Category: peopleBody, Subcategory: hand-fingers-open, Sort order: 173
    case blackHeart = "🖤" // Category: smileysEmotion, Subcategory: heart, Sort order: 152
    case desktopComputer = "🖥️" // Category: objects, Subcategory: computer, Sort order: 1236
    case printer = "🖨️" // Category: objects, Subcategory: computer, Sort order: 1237
    case computerMouse = "🖱️" // Category: objects, Subcategory: computer, Sort order: 1239
    case trackball = "🖲️" // Category: objects, Subcategory: computer, Sort order: 1240
    case framedPicture = "🖼️" // Category: activities, Subcategory: arts & crafts, Sort order: 1144
    case cardIndexDividers = "🗂️" // Category: objects, Subcategory: office, Sort order: 1312
    case cardFileBox = "🗃️" // Category: objects, Subcategory: office, Sort order: 1329
    case fileCabinet = "🗄️" // Category: objects, Subcategory: office, Sort order: 1330
    case wastebasket = "🗑️" // Category: objects, Subcategory: office, Sort order: 1331
    case spiralNotepad = "🗒️" // Category: objects, Subcategory: office, Sort order: 1315
    case spiralCalendar = "🗓️" // Category: objects, Subcategory: office, Sort order: 1316
    case clamp = "🗜️" // Category: objects, Subcategory: tool, Sort order: 1354
    case oldKey = "🗝️" // Category: objects, Subcategory: lock, Sort order: 1337
    case rolledupNewspaper = "🗞️" // Category: objects, Subcategory: book-paper, Sort order: 1275
    case dagger = "🗡️" // Category: objects, Subcategory: tool, Sort order: 1343
    case speakingHead = "🗣️" // Category: peopleBody, Subcategory: person-symbol, Sort order: 544
    case leftSpeechBubble = "🗨️" // Category: smileysEmotion, Subcategory: emotion, Sort order: 165
    case rightAngerBubble = "🗯️" // Category: smileysEmotion, Subcategory: emotion, Sort order: 166
    case ballotBoxWithBallot = "🗳️" // Category: objects, Subcategory: mail, Sort order: 1301
    case worldMap = "🗺️" // Category: travelPlaces, Subcategory: place-map, Sort order: 851
    case mountFuji = "🗻" // Category: travelPlaces, Subcategory: place-geographic, Sort order: 857
    case tokyoTower = "🗼" // Category: travelPlaces, Subcategory: place-building, Sort order: 888
    case statueOfLiberty = "🗽" // Category: travelPlaces, Subcategory: place-building, Sort order: 889
    case silhouetteOfJapan = "🗾" // Category: travelPlaces, Subcategory: place-map, Sort order: 852
    case moyai = "🗿" // Category: objects, Subcategory: other-object, Sort order: 1409
    case grinningFace = "😀" // Category: smileysEmotion, Subcategory: face-smiling, Sort order: 1
    case grinningFaceWithSmilingEyes = "😁" // Category: smileysEmotion, Subcategory: face-smiling, Sort order: 4
    case faceWithTearsOfJoy = "😂" // Category: smileysEmotion, Subcategory: face-smiling, Sort order: 8
    case smilingFaceWithOpenMouth = "😃" // Category: smileysEmotion, Subcategory: face-smiling, Sort order: 2
    case smilingFaceWithOpenMouthAndSmilingEyes = "😄" // Category: smileysEmotion, Subcategory: face-smiling, Sort order: 3
    case smilingFaceWithOpenMouthAndColdSweat = "😅" // Category: smileysEmotion, Subcategory: face-smiling, Sort order: 6
    case smilingFaceWithOpenMouthAndTightlyclosedEyes = "😆" // Category: smileysEmotion, Subcategory: face-smiling, Sort order: 5
    case smilingFaceWithHalo = "😇" // Category: smileysEmotion, Subcategory: face-smiling, Sort order: 14
    case smilingFaceWithHorns = "😈" // Category: smileysEmotion, Subcategory: face-negative, Sort order: 106
    case winkingFace = "😉" // Category: smileysEmotion, Subcategory: face-smiling, Sort order: 12
    case smilingFaceWithSmilingEyes = "😊" // Category: smileysEmotion, Subcategory: face-smiling, Sort order: 13
    case faceSavouringDeliciousFood = "😋" // Category: smileysEmotion, Subcategory: face-tongue, Sort order: 24
    case relievedFace = "😌" // Category: smileysEmotion, Subcategory: face-sleepy, Sort order: 53
    case smilingFaceWithHeartshapedEyes = "😍" // Category: smileysEmotion, Subcategory: face-affection, Sort order: 16
    case smilingFaceWithSunglasses = "😎" // Category: smileysEmotion, Subcategory: face-glasses, Sort order: 73
    case smirkingFace = "😏" // Category: smileysEmotion, Subcategory: face-neutral-skeptical, Sort order: 44
    case neutralFace = "😐" // Category: smileysEmotion, Subcategory: face-neutral-skeptical, Sort order: 39
    case expressionlessFace = "😑" // Category: smileysEmotion, Subcategory: face-neutral-skeptical, Sort order: 40
    case unamusedFace = "😒" // Category: smileysEmotion, Subcategory: face-neutral-skeptical, Sort order: 45
    case faceWithColdSweat = "😓" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 98
    case pensiveFace = "😔" // Category: smileysEmotion, Subcategory: face-sleepy, Sort order: 54
    case confusedFace = "😕" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 76
    case confoundedFace = "😖" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 95
    case kissingFace = "😗" // Category: smileysEmotion, Subcategory: face-affection, Sort order: 19
    case faceThrowingAKiss = "😘" // Category: smileysEmotion, Subcategory: face-affection, Sort order: 18
    case kissingFaceWithSmilingEyes = "😙" // Category: smileysEmotion, Subcategory: face-affection, Sort order: 22
    case kissingFaceWithClosedEyes = "😚" // Category: smileysEmotion, Subcategory: face-affection, Sort order: 21
    case faceWithStuckoutTongue = "😛" // Category: smileysEmotion, Subcategory: face-tongue, Sort order: 25
    case faceWithStuckoutTongueAndWinkingEye = "😜" // Category: smileysEmotion, Subcategory: face-tongue, Sort order: 26
    case faceWithStuckoutTongueAndTightlyclosedEyes = "😝" // Category: smileysEmotion, Subcategory: face-tongue, Sort order: 28
    case disappointedFace = "😞" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 97
    case worriedFace = "😟" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 78
    case angryFace = "😠" // Category: smileysEmotion, Subcategory: face-negative, Sort order: 104
    case poutingFace = "😡" // Category: smileysEmotion, Subcategory: face-negative, Sort order: 103
    case cryingFace = "😢" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 92
    case perseveringFace = "😣" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 96
    case faceWithLookOfTriumph = "😤" // Category: smileysEmotion, Subcategory: face-negative, Sort order: 102
    case disappointedButRelievedFace = "😥" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 91
    case frowningFaceWithOpenMouth = "😦" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 87
    case anguishedFace = "😧" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 88
    case fearfulFace = "😨" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 89
    case wearyFace = "😩" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 99
    case sleepyFace = "😪" // Category: smileysEmotion, Subcategory: face-sleepy, Sort order: 55
    case tiredFace = "😫" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 100
    case grimacingFace = "😬" // Category: smileysEmotion, Subcategory: face-neutral-skeptical, Sort order: 47
    case loudlyCryingFace = "😭" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 93
    case faceExhaling = "😮‍💨" // Category: smileysEmotion, Subcategory: face-neutral-skeptical, Sort order: 48
    case faceWithOpenMouth = "😮" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 81
    case hushedFace = "😯" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 82
    case faceWithOpenMouthAndColdSweat = "😰" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 90
    case faceScreamingInFear = "😱" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 94
    case astonishedFace = "😲" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 83
    case flushedFace = "😳" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 84
    case sleepingFace = "😴" // Category: smileysEmotion, Subcategory: face-sleepy, Sort order: 57
    case faceWithSpiralEyes = "😵‍💫" // Category: smileysEmotion, Subcategory: face-unwell, Sort order: 68
    case dizzyFace = "😵" // Category: smileysEmotion, Subcategory: face-unwell, Sort order: 67
    case faceInClouds = "😶‍🌫️" // Category: smileysEmotion, Subcategory: face-neutral-skeptical, Sort order: 43
    case faceWithoutMouth = "😶" // Category: smileysEmotion, Subcategory: face-neutral-skeptical, Sort order: 41
    case faceWithMedicalMask = "😷" // Category: smileysEmotion, Subcategory: face-unwell, Sort order: 58
    case grinningCatFaceWithSmilingEyes = "😸" // Category: smileysEmotion, Subcategory: cat-face, Sort order: 119
    case catFaceWithTearsOfJoy = "😹" // Category: smileysEmotion, Subcategory: cat-face, Sort order: 120
    case smilingCatFaceWithOpenMouth = "😺" // Category: smileysEmotion, Subcategory: cat-face, Sort order: 118
    case smilingCatFaceWithHeartshapedEyes = "😻" // Category: smileysEmotion, Subcategory: cat-face, Sort order: 121
    case catFaceWithWrySmile = "😼" // Category: smileysEmotion, Subcategory: cat-face, Sort order: 122
    case kissingCatFaceWithClosedEyes = "😽" // Category: smileysEmotion, Subcategory: cat-face, Sort order: 123
    case poutingCatFace = "😾" // Category: smileysEmotion, Subcategory: cat-face, Sort order: 126
    case cryingCatFace = "😿" // Category: smileysEmotion, Subcategory: cat-face, Sort order: 125
    case wearyCatFace = "🙀" // Category: smileysEmotion, Subcategory: cat-face, Sort order: 124
    case slightlyFrowningFace = "🙁" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 79
    case headShakingHorizontally = "🙂‍↔️" // Category: smileysEmotion, Subcategory: face-neutral-skeptical, Sort order: 51
    case headShakingVertically = "🙂‍↕️" // Category: smileysEmotion, Subcategory: face-neutral-skeptical, Sort order: 52
    case slightlySmilingFace = "🙂" // Category: smileysEmotion, Subcategory: face-smiling, Sort order: 9
    case upsidedownFace = "🙃" // Category: smileysEmotion, Subcategory: face-smiling, Sort order: 10
    case faceWithRollingEyes = "🙄" // Category: smileysEmotion, Subcategory: face-neutral-skeptical, Sort order: 46
    case womanGesturingNo = "🙅‍♀️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 266
    case manGesturingNo = "🙅‍♂️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 265
    case faceWithNoGoodGesture = "🙅" // Category: peopleBody, Subcategory: person-gesture, Sort order: 264
    case womanGesturingOk = "🙆‍♀️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 269
    case manGesturingOk = "🙆‍♂️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 268
    case faceWithOkGesture = "🙆" // Category: peopleBody, Subcategory: person-gesture, Sort order: 267
    case womanBowing = "🙇‍♀️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 281
    case manBowing = "🙇‍♂️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 280
    case personBowingDeeply = "🙇" // Category: peopleBody, Subcategory: person-gesture, Sort order: 279
    case seenoevilMonkey = "🙈" // Category: smileysEmotion, Subcategory: monkey-face, Sort order: 127
    case hearnoevilMonkey = "🙉" // Category: smileysEmotion, Subcategory: monkey-face, Sort order: 128
    case speaknoevilMonkey = "🙊" // Category: smileysEmotion, Subcategory: monkey-face, Sort order: 129
    case womanRaisingHand = "🙋‍♀️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 275
    case manRaisingHand = "🙋‍♂️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 274
    case happyPersonRaisingOneHand = "🙋" // Category: peopleBody, Subcategory: person-gesture, Sort order: 273
    case personRaisingBothHandsInCelebration = "🙌" // Category: peopleBody, Subcategory: hands, Sort order: 203
    case womanFrowning = "🙍‍♀️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 260
    case manFrowning = "🙍‍♂️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 259
    case personFrowning = "🙍" // Category: peopleBody, Subcategory: person-gesture, Sort order: 258
    case womanPouting = "🙎‍♀️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 263
    case manPouting = "🙎‍♂️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 262
    case personWithPoutingFace = "🙎" // Category: peopleBody, Subcategory: person-gesture, Sort order: 261
    case personWithFoldedHands = "🙏" // Category: peopleBody, Subcategory: hands, Sort order: 208
    case rocket = "🚀" // Category: travelPlaces, Subcategory: transport-air, Sort order: 983
    case helicopter = "🚁" // Category: travelPlaces, Subcategory: transport-air, Sort order: 978
    case steamLocomotive = "🚂" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 913
    case railwayCar = "🚃" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 914
    case highspeedTrain = "🚄" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 915
    case highspeedTrainWithBulletNose = "🚅" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 916
    case train = "🚆" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 917
    case metro = "🚇" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 918
    case lightRail = "🚈" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 919
    case station = "🚉" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 920
    case tram = "🚊" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 921
    case tramCar = "🚋" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 924
    case bus = "🚌" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 925
    case oncomingBus = "🚍" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 926
    case trolleybus = "🚎" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 927
    case busStop = "🚏" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 952
    case minibus = "🚐" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 928
    case ambulance = "🚑" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 929
    case fireEngine = "🚒" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 930
    case policeCar = "🚓" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 931
    case oncomingPoliceCar = "🚔" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 932
    case taxi = "🚕" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 933
    case oncomingTaxi = "🚖" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 934
    case automobile = "🚗" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 935
    case oncomingAutomobile = "🚘" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 936
    case recreationalVehicle = "🚙" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 937
    case deliveryTruck = "🚚" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 939
    case articulatedLorry = "🚛" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 940
    case tractor = "🚜" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 941
    case monorail = "🚝" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 922
    case mountainRailway = "🚞" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 923
    case suspensionRailway = "🚟" // Category: travelPlaces, Subcategory: transport-air, Sort order: 979
    case mountainCableway = "🚠" // Category: travelPlaces, Subcategory: transport-air, Sort order: 980
    case aerialTramway = "🚡" // Category: travelPlaces, Subcategory: transport-air, Sort order: 981
    case ship = "🚢" // Category: travelPlaces, Subcategory: transport-water, Sort order: 971
    case womanRowingBoat = "🚣‍♀️" // Category: peopleBody, Subcategory: person-sport, Sort order: 471
    case manRowingBoat = "🚣‍♂️" // Category: peopleBody, Subcategory: person-sport, Sort order: 470
    case rowboat = "🚣" // Category: peopleBody, Subcategory: person-sport, Sort order: 469
    case speedboat = "🚤" // Category: travelPlaces, Subcategory: transport-water, Sort order: 967
    case horizontalTrafficLight = "🚥" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 959
    case verticalTrafficLight = "🚦" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 960
    case constructionSign = "🚧" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 962
    case policeCarsRevolvingLight = "🚨" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 958
    case triangularFlagOnPost = "🚩" // Category: flags, Subcategory: flag, Sort order: 1636
    case door = "🚪" // Category: objects, Subcategory: household, Sort order: 1378
    case noEntrySign = "🚫" // Category: symbols, Subcategory: warning, Sort order: 1428
    case smokingSymbol = "🚬" // Category: objects, Subcategory: other-object, Sort order: 1403
    case noSmokingSymbol = "🚭" // Category: symbols, Subcategory: warning, Sort order: 1430
    case putLitterInItsPlaceSymbol = "🚮" // Category: symbols, Subcategory: transport-sign, Sort order: 1413
    case doNotLitterSymbol = "🚯" // Category: symbols, Subcategory: warning, Sort order: 1431
    case potableWaterSymbol = "🚰" // Category: symbols, Subcategory: transport-sign, Sort order: 1414
    case nonpotableWaterSymbol = "🚱" // Category: symbols, Subcategory: warning, Sort order: 1432
    case bicycle = "🚲" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 948
    case noBicycles = "🚳" // Category: symbols, Subcategory: warning, Sort order: 1429
    case womanBiking = "🚴‍♀️" // Category: peopleBody, Subcategory: person-sport, Sort order: 483
    case manBiking = "🚴‍♂️" // Category: peopleBody, Subcategory: person-sport, Sort order: 482
    case bicyclist = "🚴" // Category: peopleBody, Subcategory: person-sport, Sort order: 481
    case womanMountainBiking = "🚵‍♀️" // Category: peopleBody, Subcategory: person-sport, Sort order: 486
    case manMountainBiking = "🚵‍♂️" // Category: peopleBody, Subcategory: person-sport, Sort order: 485
    case mountainBicyclist = "🚵" // Category: peopleBody, Subcategory: person-sport, Sort order: 484
    case womanWalking = "🚶‍♀️" // Category: peopleBody, Subcategory: person-activity, Sort order: 410
    case womanWalkingFacingRight = "🚶‍♀️‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 412
    case manWalking = "🚶‍♂️" // Category: peopleBody, Subcategory: person-activity, Sort order: 409
    case manWalkingFacingRight = "🚶‍♂️‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 413
    case personWalkingFacingRight = "🚶‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 411
    case pedestrian = "🚶" // Category: peopleBody, Subcategory: person-activity, Sort order: 408
    case noPedestrians = "🚷" // Category: symbols, Subcategory: warning, Sort order: 1433
    case childrenCrossing = "🚸" // Category: symbols, Subcategory: warning, Sort order: 1426
    case mensSymbol = "🚹" // Category: symbols, Subcategory: transport-sign, Sort order: 1416
    case womensSymbol = "🚺" // Category: symbols, Subcategory: transport-sign, Sort order: 1417
    case restroom = "🚻" // Category: symbols, Subcategory: transport-sign, Sort order: 1418
    case babySymbol = "🚼" // Category: symbols, Subcategory: transport-sign, Sort order: 1419
    case toilet = "🚽" // Category: objects, Subcategory: household, Sort order: 1385
    case waterCloset = "🚾" // Category: symbols, Subcategory: transport-sign, Sort order: 1420
    case shower = "🚿" // Category: objects, Subcategory: household, Sort order: 1387
    case bath = "🛀" // Category: peopleBody, Subcategory: person-resting, Sort order: 505
    case bathtub = "🛁" // Category: objects, Subcategory: household, Sort order: 1388
    case passportControl = "🛂" // Category: symbols, Subcategory: transport-sign, Sort order: 1421
    case customs = "🛃" // Category: symbols, Subcategory: transport-sign, Sort order: 1422
    case baggageClaim = "🛄" // Category: symbols, Subcategory: transport-sign, Sort order: 1423
    case leftLuggage = "🛅" // Category: symbols, Subcategory: transport-sign, Sort order: 1424
    case couchAndLamp = "🛋️" // Category: objects, Subcategory: household, Sort order: 1383
    case sleepingAccommodation = "🛌" // Category: peopleBody, Subcategory: person-resting, Sort order: 506
    case shoppingBags = "🛍️" // Category: objects, Subcategory: clothing, Sort order: 1174
    case bellhopBell = "🛎️" // Category: travelPlaces, Subcategory: hotel, Sort order: 985
    case bed = "🛏️" // Category: objects, Subcategory: household, Sort order: 1382
    case placeOfWorship = "🛐" // Category: symbols, Subcategory: religion, Sort order: 1459
    case octagonalSign = "🛑" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 961
    case shoppingTrolley = "🛒" // Category: objects, Subcategory: household, Sort order: 1402
    case hinduTemple = "🛕" // Category: travelPlaces, Subcategory: place-religious, Sort order: 892
    case hut = "🛖" // Category: travelPlaces, Subcategory: place-building, Sort order: 869
    case elevator = "🛗" // Category: objects, Subcategory: household, Sort order: 1379
    case wireless = "🛜" // Category: symbols, Subcategory: av-symbol, Sort order: 1507
    case playgroundSlide = "🛝" // Category: travelPlaces, Subcategory: place-other, Sort order: 908
    case wheel = "🛞" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 957
    case ringBuoy = "🛟" // Category: travelPlaces, Subcategory: transport-water, Sort order: 964
    case hammerAndWrench = "🛠️" // Category: objects, Subcategory: tool, Sort order: 1342
    case shield = "🛡️" // Category: objects, Subcategory: tool, Sort order: 1348
    case oilDrum = "🛢️" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 955
    case motorway = "🛣️" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 953
    case railwayTrack = "🛤️" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 954
    case motorBoat = "🛥️" // Category: travelPlaces, Subcategory: transport-water, Sort order: 970
    case smallAirplane = "🛩️" // Category: travelPlaces, Subcategory: transport-air, Sort order: 973
    case airplaneDeparture = "🛫" // Category: travelPlaces, Subcategory: transport-air, Sort order: 974
    case airplaneArriving = "🛬" // Category: travelPlaces, Subcategory: transport-air, Sort order: 975
    case satellite = "🛰️" // Category: travelPlaces, Subcategory: transport-air, Sort order: 982
    case passengerShip = "🛳️" // Category: travelPlaces, Subcategory: transport-water, Sort order: 968
    case scooter = "🛴" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 949
    case motorScooter = "🛵" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 944
    case canoe = "🛶" // Category: travelPlaces, Subcategory: transport-water, Sort order: 966
    case sled = "🛷" // Category: activities, Subcategory: sport, Sort order: 1117
    case flyingSaucer = "🛸" // Category: travelPlaces, Subcategory: transport-air, Sort order: 984
    case skateboard = "🛹" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 950
    case autoRickshaw = "🛺" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 947
    case pickupTruck = "🛻" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 938
    case rollerSkate = "🛼" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 951
    case largeOrangeCircle = "🟠" // Category: symbols, Subcategory: geometric, Sort order: 1602
    case largeYellowCircle = "🟡" // Category: symbols, Subcategory: geometric, Sort order: 1603
    case largeGreenCircle = "🟢" // Category: symbols, Subcategory: geometric, Sort order: 1604
    case largePurpleCircle = "🟣" // Category: symbols, Subcategory: geometric, Sort order: 1606
    case largeBrownCircle = "🟤" // Category: symbols, Subcategory: geometric, Sort order: 1607
    case largeRedSquare = "🟥" // Category: symbols, Subcategory: geometric, Sort order: 1610
    case largeBlueSquare = "🟦" // Category: symbols, Subcategory: geometric, Sort order: 1614
    case largeOrangeSquare = "🟧" // Category: symbols, Subcategory: geometric, Sort order: 1611
    case largeYellowSquare = "🟨" // Category: symbols, Subcategory: geometric, Sort order: 1612
    case largeGreenSquare = "🟩" // Category: symbols, Subcategory: geometric, Sort order: 1613
    case largePurpleSquare = "🟪" // Category: symbols, Subcategory: geometric, Sort order: 1615
    case largeBrownSquare = "🟫" // Category: symbols, Subcategory: geometric, Sort order: 1616
    case heavyEqualsSign = "🟰" // Category: symbols, Subcategory: math, Sort order: 1517
    case pinchedFingers = "🤌" // Category: peopleBody, Subcategory: hand-fingers-partial, Sort order: 181
    case whiteHeart = "🤍" // Category: smileysEmotion, Subcategory: heart, Sort order: 154
    case brownHeart = "🤎" // Category: smileysEmotion, Subcategory: heart, Sort order: 151
    case pinchingHand = "🤏" // Category: peopleBody, Subcategory: hand-fingers-partial, Sort order: 182
    case zippermouthFace = "🤐" // Category: smileysEmotion, Subcategory: face-neutral-skeptical, Sort order: 37
    case moneymouthFace = "🤑" // Category: smileysEmotion, Subcategory: face-tongue, Sort order: 29
    case faceWithThermometer = "🤒" // Category: smileysEmotion, Subcategory: face-unwell, Sort order: 59
    case nerdFace = "🤓" // Category: smileysEmotion, Subcategory: face-glasses, Sort order: 74
    case thinkingFace = "🤔" // Category: smileysEmotion, Subcategory: face-hand, Sort order: 35
    case faceWithHeadbandage = "🤕" // Category: smileysEmotion, Subcategory: face-unwell, Sort order: 60
    case robotFace = "🤖" // Category: smileysEmotion, Subcategory: face-costume, Sort order: 117
    case huggingFace = "🤗" // Category: smileysEmotion, Subcategory: face-hand, Sort order: 30
    case signOfTheHorns = "🤘" // Category: peopleBody, Subcategory: hand-fingers-partial, Sort order: 187
    case callMeHand = "🤙" // Category: peopleBody, Subcategory: hand-fingers-partial, Sort order: 188
    case raisedBackOfHand = "🤚" // Category: peopleBody, Subcategory: hand-fingers-open, Sort order: 170
    case leftfacingFist = "🤛" // Category: peopleBody, Subcategory: hand-fingers-closed, Sort order: 200
    case rightfacingFist = "🤜" // Category: peopleBody, Subcategory: hand-fingers-closed, Sort order: 201
    case handshake = "🤝" // Category: peopleBody, Subcategory: hands, Sort order: 207
    case handWithIndexAndMiddleFingersCrossed = "🤞" // Category: peopleBody, Subcategory: hand-fingers-partial, Sort order: 184
    case iLoveYouHandSign = "🤟" // Category: peopleBody, Subcategory: hand-fingers-partial, Sort order: 186
    case faceWithCowboyHat = "🤠" // Category: smileysEmotion, Subcategory: face-hat, Sort order: 70
    case clownFace = "🤡" // Category: smileysEmotion, Subcategory: face-costume, Sort order: 111
    case nauseatedFace = "🤢" // Category: smileysEmotion, Subcategory: face-unwell, Sort order: 61
    case rollingOnTheFloorLaughing = "🤣" // Category: smileysEmotion, Subcategory: face-smiling, Sort order: 7
    case droolingFace = "🤤" // Category: smileysEmotion, Subcategory: face-sleepy, Sort order: 56
    case lyingFace = "🤥" // Category: smileysEmotion, Subcategory: face-neutral-skeptical, Sort order: 49
    case womanFacepalming = "🤦‍♀️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 284
    case manFacepalming = "🤦‍♂️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 283
    case facePalm = "🤦" // Category: peopleBody, Subcategory: person-gesture, Sort order: 282
    case sneezingFace = "🤧" // Category: smileysEmotion, Subcategory: face-unwell, Sort order: 63
    case faceWithOneEyebrowRaised = "🤨" // Category: smileysEmotion, Subcategory: face-neutral-skeptical, Sort order: 38
    case grinningFaceWithStarEyes = "🤩" // Category: smileysEmotion, Subcategory: face-affection, Sort order: 17
    case grinningFaceWithOneLargeAndOneSmallEye = "🤪" // Category: smileysEmotion, Subcategory: face-tongue, Sort order: 27
    case faceWithFingerCoveringClosedLips = "🤫" // Category: smileysEmotion, Subcategory: face-hand, Sort order: 34
    case seriousFaceWithSymbolsCoveringMouth = "🤬" // Category: smileysEmotion, Subcategory: face-negative, Sort order: 105
    case smilingFaceWithSmilingEyesAndHandCoveringMouth = "🤭" // Category: smileysEmotion, Subcategory: face-hand, Sort order: 31
    case faceWithOpenMouthVomiting = "🤮" // Category: smileysEmotion, Subcategory: face-unwell, Sort order: 62
    case shockedFaceWithExplodingHead = "🤯" // Category: smileysEmotion, Subcategory: face-unwell, Sort order: 69
    case pregnantWoman = "🤰" // Category: peopleBody, Subcategory: person-role, Sort order: 363
    case breastfeeding = "🤱" // Category: peopleBody, Subcategory: person-role, Sort order: 366
    case palmsUpTogether = "🤲" // Category: peopleBody, Subcategory: hands, Sort order: 206
    case selfie = "🤳" // Category: peopleBody, Subcategory: hand-prop, Sort order: 211
    case prince = "🤴" // Category: peopleBody, Subcategory: person-role, Sort order: 350
    case womanInTuxedo = "🤵‍♀️" // Category: peopleBody, Subcategory: person-role, Sort order: 359
    case manInTuxedo = "🤵‍♂️" // Category: peopleBody, Subcategory: person-role, Sort order: 358
    case motherChristmas = "🤶" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 372
    case womanShrugging = "🤷‍♀️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 287
    case manShrugging = "🤷‍♂️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 286
    case shrug = "🤷" // Category: peopleBody, Subcategory: person-gesture, Sort order: 285
    case womanCartwheeling = "🤸‍♀️" // Category: peopleBody, Subcategory: person-sport, Sort order: 489
    case manCartwheeling = "🤸‍♂️" // Category: peopleBody, Subcategory: person-sport, Sort order: 488
    case personDoingCartwheel = "🤸" // Category: peopleBody, Subcategory: person-sport, Sort order: 487
    case womanJuggling = "🤹‍♀️" // Category: peopleBody, Subcategory: person-sport, Sort order: 501
    case manJuggling = "🤹‍♂️" // Category: peopleBody, Subcategory: person-sport, Sort order: 500
    case juggling = "🤹" // Category: peopleBody, Subcategory: person-sport, Sort order: 499
    case fencer = "🤺" // Category: peopleBody, Subcategory: person-sport, Sort order: 459
    case womenWrestling = "🤼‍♀️" // Category: peopleBody, Subcategory: person-sport, Sort order: 492
    case menWrestling = "🤼‍♂️" // Category: peopleBody, Subcategory: person-sport, Sort order: 491
    case wrestlers = "🤼" // Category: peopleBody, Subcategory: person-sport, Sort order: 490
    case womanPlayingWaterPolo = "🤽‍♀️" // Category: peopleBody, Subcategory: person-sport, Sort order: 495
    case manPlayingWaterPolo = "🤽‍♂️" // Category: peopleBody, Subcategory: person-sport, Sort order: 494
    case waterPolo = "🤽" // Category: peopleBody, Subcategory: person-sport, Sort order: 493
    case womanPlayingHandball = "🤾‍♀️" // Category: peopleBody, Subcategory: person-sport, Sort order: 498
    case manPlayingHandball = "🤾‍♂️" // Category: peopleBody, Subcategory: person-sport, Sort order: 497
    case handball = "🤾" // Category: peopleBody, Subcategory: person-sport, Sort order: 496
    case divingMask = "🤿" // Category: activities, Subcategory: sport, Sort order: 1114
    case wiltedFlower = "🥀" // Category: animalsNature, Subcategory: plant-flower, Sort order: 690
    case drumWithDrumsticks = "🥁" // Category: objects, Subcategory: musical-instrument, Sort order: 1222
    case clinkingGlasses = "🥂" // Category: foodDrink, Subcategory: drink, Sort order: 832
    case tumblerGlass = "🥃" // Category: foodDrink, Subcategory: drink, Sort order: 833
    case spoon = "🥄" // Category: foodDrink, Subcategory: dishware, Sort order: 843
    case goalNet = "🥅" // Category: activities, Subcategory: sport, Sort order: 1110
    case firstPlaceMedal = "🥇" // Category: activities, Subcategory: award-medal, Sort order: 1089
    case secondPlaceMedal = "🥈" // Category: activities, Subcategory: award-medal, Sort order: 1090
    case thirdPlaceMedal = "🥉" // Category: activities, Subcategory: award-medal, Sort order: 1091
    case boxingGlove = "🥊" // Category: activities, Subcategory: sport, Sort order: 1108
    case martialArtsUniform = "🥋" // Category: activities, Subcategory: sport, Sort order: 1109
    case curlingStone = "🥌" // Category: activities, Subcategory: sport, Sort order: 1118
    case lacrosseStickAndBall = "🥍" // Category: activities, Subcategory: sport, Sort order: 1105
    case softball = "🥎" // Category: activities, Subcategory: sport, Sort order: 1094
    case flyingDisc = "🥏" // Category: activities, Subcategory: sport, Sort order: 1100
    case croissant = "🥐" // Category: foodDrink, Subcategory: food-prepared, Sort order: 751
    case avocado = "🥑" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 732
    case cucumber = "🥒" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 739
    case bacon = "🥓" // Category: foodDrink, Subcategory: food-prepared, Sort order: 762
    case potato = "🥔" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 734
    case carrot = "🥕" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 735
    case baguetteBread = "🥖" // Category: foodDrink, Subcategory: food-prepared, Sort order: 752
    case greenSalad = "🥗" // Category: foodDrink, Subcategory: food-prepared, Sort order: 779
    case shallowPanOfFood = "🥘" // Category: foodDrink, Subcategory: food-prepared, Sort order: 775
    case stuffedFlatbread = "🥙" // Category: foodDrink, Subcategory: food-prepared, Sort order: 771
    case egg = "🥚" // Category: foodDrink, Subcategory: food-prepared, Sort order: 773
    case glassOfMilk = "🥛" // Category: foodDrink, Subcategory: drink, Sort order: 821
    case peanuts = "🥜" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 744
    case kiwifruit = "🥝" // Category: foodDrink, Subcategory: food-fruit, Sort order: 728
    case pancakes = "🥞" // Category: foodDrink, Subcategory: food-prepared, Sort order: 756
    case dumpling = "🥟" // Category: foodDrink, Subcategory: food-asian, Sort order: 798
    case fortuneCookie = "🥠" // Category: foodDrink, Subcategory: food-asian, Sort order: 799
    case takeoutBox = "🥡" // Category: foodDrink, Subcategory: food-asian, Sort order: 800
    case chopsticks = "🥢" // Category: foodDrink, Subcategory: dishware, Sort order: 840
    case bowlWithSpoon = "🥣" // Category: foodDrink, Subcategory: food-prepared, Sort order: 778
    case cupWithStraw = "🥤" // Category: foodDrink, Subcategory: drink, Sort order: 835
    case coconut = "🥥" // Category: foodDrink, Subcategory: food-fruit, Sort order: 731
    case broccoli = "🥦" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 741
    case pie = "🥧" // Category: foodDrink, Subcategory: food-sweet, Sort order: 814
    case pretzel = "🥨" // Category: foodDrink, Subcategory: food-prepared, Sort order: 754
    case cutOfMeat = "🥩" // Category: foodDrink, Subcategory: food-prepared, Sort order: 761
    case sandwich = "🥪" // Category: foodDrink, Subcategory: food-prepared, Sort order: 767
    case cannedFood = "🥫" // Category: foodDrink, Subcategory: food-prepared, Sort order: 783
    case leafyGreen = "🥬" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 740
    case mango = "🥭" // Category: foodDrink, Subcategory: food-fruit, Sort order: 720
    case moonCake = "🥮" // Category: foodDrink, Subcategory: food-asian, Sort order: 796
    case bagel = "🥯" // Category: foodDrink, Subcategory: food-prepared, Sort order: 755
    case smilingFaceWithSmilingEyesAndThreeHearts = "🥰" // Category: smileysEmotion, Subcategory: face-affection, Sort order: 15
    case yawningFace = "🥱" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 101
    case smilingFaceWithTear = "🥲" // Category: smileysEmotion, Subcategory: face-affection, Sort order: 23
    case faceWithPartyHornAndPartyHat = "🥳" // Category: smileysEmotion, Subcategory: face-hat, Sort order: 71
    case faceWithUnevenEyesAndWavyMouth = "🥴" // Category: smileysEmotion, Subcategory: face-unwell, Sort order: 66
    case overheatedFace = "🥵" // Category: smileysEmotion, Subcategory: face-unwell, Sort order: 64
    case freezingFace = "🥶" // Category: smileysEmotion, Subcategory: face-unwell, Sort order: 65
    case ninja = "🥷" // Category: peopleBody, Subcategory: person-role, Sort order: 345
    case disguisedFace = "🥸" // Category: smileysEmotion, Subcategory: face-hat, Sort order: 72
    case faceHoldingBackTears = "🥹" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 86
    case faceWithPleadingEyes = "🥺" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 85
    case sari = "🥻" // Category: objects, Subcategory: clothing, Sort order: 1164
    case labCoat = "🥼" // Category: objects, Subcategory: clothing, Sort order: 1153
    case goggles = "🥽" // Category: objects, Subcategory: clothing, Sort order: 1152
    case hikingBoot = "🥾" // Category: objects, Subcategory: clothing, Sort order: 1179
    case flatShoe = "🥿" // Category: objects, Subcategory: clothing, Sort order: 1180
    case crab = "🦀" // Category: foodDrink, Subcategory: food-marine, Sort order: 801
    case lionFace = "🦁" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 574
    case scorpion = "🦂" // Category: animalsNature, Subcategory: animal-bug, Sort order: 679
    case turkey = "🦃" // Category: animalsNature, Subcategory: animal-bird, Sort order: 625
    case unicornFace = "🦄" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 582
    case eagle = "🦅" // Category: animalsNature, Subcategory: animal-bird, Sort order: 634
    case duck = "🦆" // Category: animalsNature, Subcategory: animal-bird, Sort order: 635
    case bat = "🦇" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 614
    case shark = "🦈" // Category: animalsNature, Subcategory: animal-marine, Sort order: 663
    case owl = "🦉" // Category: animalsNature, Subcategory: animal-bird, Sort order: 637
    case foxFace = "🦊" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 569
    case butterfly = "🦋" // Category: animalsNature, Subcategory: animal-bug, Sort order: 669
    case deer = "🦌" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 584
    case gorilla = "🦍" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 561
    case lizard = "🦎" // Category: animalsNature, Subcategory: animal-reptile, Sort order: 650
    case rhinoceros = "🦏" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 603
    case shrimp = "🦐" // Category: foodDrink, Subcategory: food-marine, Sort order: 803
    case squid = "🦑" // Category: foodDrink, Subcategory: food-marine, Sort order: 804
    case giraffeFace = "🦒" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 600
    case zebraFace = "🦓" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 583
    case hedgehog = "🦔" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 613
    case sauropod = "🦕" // Category: animalsNature, Subcategory: animal-reptile, Sort order: 654
    case trex = "🦖" // Category: animalsNature, Subcategory: animal-reptile, Sort order: 655
    case cricket = "🦗" // Category: animalsNature, Subcategory: animal-bug, Sort order: 675
    case kangaroo = "🦘" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 622
    case llama = "🦙" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 599
    case peacock = "🦚" // Category: animalsNature, Subcategory: animal-bird, Sort order: 641
    case hippopotamus = "🦛" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 604
    case parrot = "🦜" // Category: animalsNature, Subcategory: animal-bird, Sort order: 642
    case raccoon = "🦝" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 570
    case lobster = "🦞" // Category: foodDrink, Subcategory: food-marine, Sort order: 802
    case mosquito = "🦟" // Category: animalsNature, Subcategory: animal-bug, Sort order: 680
    case microbe = "🦠" // Category: animalsNature, Subcategory: animal-bug, Sort order: 683
    case badger = "🦡" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 623
    case swan = "🦢" // Category: animalsNature, Subcategory: animal-bird, Sort order: 636
    case mammoth = "🦣" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 602
    case dodo = "🦤" // Category: animalsNature, Subcategory: animal-bird, Sort order: 638
    case sloth = "🦥" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 619
    case otter = "🦦" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 620
    case orangutan = "🦧" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 562
    case skunk = "🦨" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 621
    case flamingo = "🦩" // Category: animalsNature, Subcategory: animal-bird, Sort order: 640
    case oyster = "🦪" // Category: foodDrink, Subcategory: food-marine, Sort order: 805
    case beaver = "🦫" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 612
    case bison = "🦬" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 585
    case seal = "🦭" // Category: animalsNature, Subcategory: animal-marine, Sort order: 659
    case guideDog = "🦮" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 565
    case probingCane = "🦯" // Category: objects, Subcategory: tool, Sort order: 1356
    case bone = "🦴" // Category: peopleBody, Subcategory: body-parts, Sort order: 224
    case leg = "🦵" // Category: peopleBody, Subcategory: body-parts, Sort order: 215
    case foot = "🦶" // Category: peopleBody, Subcategory: body-parts, Sort order: 216
    case tooth = "🦷" // Category: peopleBody, Subcategory: body-parts, Sort order: 223
    case womanSuperhero = "🦸‍♀️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 376
    case manSuperhero = "🦸‍♂️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 375
    case superhero = "🦸" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 374
    case womanSupervillain = "🦹‍♀️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 379
    case manSupervillain = "🦹‍♂️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 378
    case supervillain = "🦹" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 377
    case safetyVest = "🦺" // Category: objects, Subcategory: clothing, Sort order: 1154
    case earWithHearingAid = "🦻" // Category: peopleBody, Subcategory: body-parts, Sort order: 218
    case motorizedWheelchair = "🦼" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 946
    case manualWheelchair = "🦽" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 945
    case mechanicalArm = "🦾" // Category: peopleBody, Subcategory: body-parts, Sort order: 213
    case mechanicalLeg = "🦿" // Category: peopleBody, Subcategory: body-parts, Sort order: 214
    case cheeseWedge = "🧀" // Category: foodDrink, Subcategory: food-prepared, Sort order: 758
    case cupcake = "🧁" // Category: foodDrink, Subcategory: food-sweet, Sort order: 813
    case saltShaker = "🧂" // Category: foodDrink, Subcategory: food-prepared, Sort order: 782
    case beverageBox = "🧃" // Category: foodDrink, Subcategory: drink, Sort order: 837
    case garlic = "🧄" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 742
    case onion = "🧅" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 743
    case falafel = "🧆" // Category: foodDrink, Subcategory: food-prepared, Sort order: 772
    case waffle = "🧇" // Category: foodDrink, Subcategory: food-prepared, Sort order: 757
    case butter = "🧈" // Category: foodDrink, Subcategory: food-prepared, Sort order: 781
    case mateDrink = "🧉" // Category: foodDrink, Subcategory: drink, Sort order: 838
    case iceCube = "🧊" // Category: foodDrink, Subcategory: drink, Sort order: 839
    case bubbleTea = "🧋" // Category: foodDrink, Subcategory: drink, Sort order: 836
    case troll = "🧌" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 401
    case womanStanding = "🧍‍♀️" // Category: peopleBody, Subcategory: person-activity, Sort order: 416
    case manStanding = "🧍‍♂️" // Category: peopleBody, Subcategory: person-activity, Sort order: 415
    case standingPerson = "🧍" // Category: peopleBody, Subcategory: person-activity, Sort order: 414
    case womanKneeling = "🧎‍♀️" // Category: peopleBody, Subcategory: person-activity, Sort order: 419
    case womanKneelingFacingRight = "🧎‍♀️‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 421
    case manKneeling = "🧎‍♂️" // Category: peopleBody, Subcategory: person-activity, Sort order: 418
    case manKneelingFacingRight = "🧎‍♂️‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 422
    case personKneelingFacingRight = "🧎‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 420
    case kneelingPerson = "🧎" // Category: peopleBody, Subcategory: person-activity, Sort order: 417
    case deafWoman = "🧏‍♀️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 278
    case deafMan = "🧏‍♂️" // Category: peopleBody, Subcategory: person-gesture, Sort order: 277
    case deafPerson = "🧏" // Category: peopleBody, Subcategory: person-gesture, Sort order: 276
    case faceWithMonocle = "🧐" // Category: smileysEmotion, Subcategory: face-glasses, Sort order: 75
    case farmer = "🧑‍🌾" // Category: peopleBody, Subcategory: person-role, Sort order: 300
    case cook = "🧑‍🍳" // Category: peopleBody, Subcategory: person-role, Sort order: 303
    case personFeedingBaby = "🧑‍🍼" // Category: peopleBody, Subcategory: person-role, Sort order: 369
    case mxClaus = "🧑‍🎄" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 373
    case student = "🧑‍🎓" // Category: peopleBody, Subcategory: person-role, Sort order: 291
    case singer = "🧑‍🎤" // Category: peopleBody, Subcategory: person-role, Sort order: 321
    case artist = "🧑‍🎨" // Category: peopleBody, Subcategory: person-role, Sort order: 324
    case teacher = "🧑‍🏫" // Category: peopleBody, Subcategory: person-role, Sort order: 294
    case factoryWorker = "🧑‍🏭" // Category: peopleBody, Subcategory: person-role, Sort order: 309
    case technologist = "🧑‍💻" // Category: peopleBody, Subcategory: person-role, Sort order: 318
    case officeWorker = "🧑‍💼" // Category: peopleBody, Subcategory: person-role, Sort order: 312
    case mechanic = "🧑‍🔧" // Category: peopleBody, Subcategory: person-role, Sort order: 306
    case scientist = "🧑‍🔬" // Category: peopleBody, Subcategory: person-role, Sort order: 315
    case astronaut = "🧑‍🚀" // Category: peopleBody, Subcategory: person-role, Sort order: 330
    case firefighter = "🧑‍🚒" // Category: peopleBody, Subcategory: person-role, Sort order: 333
    case peopleHoldingHands = "🧑‍🤝‍🧑" // Category: peopleBody, Subcategory: family, Sort order: 507
    case personWithWhiteCaneFacingRight = "🧑‍🦯‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 424
    case personWithWhiteCane = "🧑‍🦯" // Category: peopleBody, Subcategory: person-activity, Sort order: 423
    case personRedHair = "🧑‍🦰" // Category: peopleBody, Subcategory: person, Sort order: 246
    case personCurlyHair = "🧑‍🦱" // Category: peopleBody, Subcategory: person, Sort order: 248
    case personBald = "🧑‍🦲" // Category: peopleBody, Subcategory: person, Sort order: 252
    case personWhiteHair = "🧑‍🦳" // Category: peopleBody, Subcategory: person, Sort order: 250
    case personInMotorizedWheelchairFacingRight = "🧑‍🦼‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 430
    case personInMotorizedWheelchair = "🧑‍🦼" // Category: peopleBody, Subcategory: person-activity, Sort order: 429
    case personInManualWheelchairFacingRight = "🧑‍🦽‍➡️" // Category: peopleBody, Subcategory: person-activity, Sort order: 436
    case personInManualWheelchair = "🧑‍🦽" // Category: peopleBody, Subcategory: person-activity, Sort order: 435
    case familyAdultAdultChild = "🧑‍🧑‍🧒" // Category: peopleBody, Subcategory: person-symbol, Sort order: 549
    case familyAdultAdultChildChild = "🧑‍🧑‍🧒‍🧒" // Category: peopleBody, Subcategory: person-symbol, Sort order: 550
    case familyAdultChildChild = "🧑‍🧒‍🧒" // Category: peopleBody, Subcategory: person-symbol, Sort order: 552
    case familyAdultChild = "🧑‍🧒" // Category: peopleBody, Subcategory: person-symbol, Sort order: 551
    case healthWorker = "🧑‍⚕️" // Category: peopleBody, Subcategory: person-role, Sort order: 288
    case judge = "🧑‍⚖️" // Category: peopleBody, Subcategory: person-role, Sort order: 297
    case pilot = "🧑‍✈️" // Category: peopleBody, Subcategory: person-role, Sort order: 327
    case adult = "🧑" // Category: peopleBody, Subcategory: person, Sort order: 234
    case child = "🧒" // Category: peopleBody, Subcategory: person, Sort order: 231
    case olderAdult = "🧓" // Category: peopleBody, Subcategory: person, Sort order: 255
    case womanBeard = "🧔‍♀️" // Category: peopleBody, Subcategory: person, Sort order: 239
    case manBeard = "🧔‍♂️" // Category: peopleBody, Subcategory: person, Sort order: 238
    case beardedPerson = "🧔" // Category: peopleBody, Subcategory: person, Sort order: 237
    case personWithHeadscarf = "🧕" // Category: peopleBody, Subcategory: person-role, Sort order: 356
    case womanInSteamyRoom = "🧖‍♀️" // Category: peopleBody, Subcategory: person-activity, Sort order: 455
    case manInSteamyRoom = "🧖‍♂️" // Category: peopleBody, Subcategory: person-activity, Sort order: 454
    case personInSteamyRoom = "🧖" // Category: peopleBody, Subcategory: person-activity, Sort order: 453
    case womanClimbing = "🧗‍♀️" // Category: peopleBody, Subcategory: person-activity, Sort order: 458
    case manClimbing = "🧗‍♂️" // Category: peopleBody, Subcategory: person-activity, Sort order: 457
    case personClimbing = "🧗" // Category: peopleBody, Subcategory: person-activity, Sort order: 456
    case womanInLotusPosition = "🧘‍♀️" // Category: peopleBody, Subcategory: person-resting, Sort order: 504
    case manInLotusPosition = "🧘‍♂️" // Category: peopleBody, Subcategory: person-resting, Sort order: 503
    case personInLotusPosition = "🧘" // Category: peopleBody, Subcategory: person-resting, Sort order: 502
    case womanMage = "🧙‍♀️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 382
    case manMage = "🧙‍♂️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 381
    case mage = "🧙" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 380
    case womanFairy = "🧚‍♀️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 385
    case manFairy = "🧚‍♂️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 384
    case fairy = "🧚" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 383
    case womanVampire = "🧛‍♀️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 388
    case manVampire = "🧛‍♂️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 387
    case vampire = "🧛" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 386
    case mermaid = "🧜‍♀️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 391
    case merman = "🧜‍♂️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 390
    case merperson = "🧜" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 389
    case womanElf = "🧝‍♀️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 394
    case manElf = "🧝‍♂️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 393
    case elf = "🧝" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 392
    case womanGenie = "🧞‍♀️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 397
    case manGenie = "🧞‍♂️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 396
    case genie = "🧞" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 395
    case womanZombie = "🧟‍♀️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 400
    case manZombie = "🧟‍♂️" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 399
    case zombie = "🧟" // Category: peopleBody, Subcategory: person-fantasy, Sort order: 398
    case brain = "🧠" // Category: peopleBody, Subcategory: body-parts, Sort order: 220
    case orangeHeart = "🧡" // Category: smileysEmotion, Subcategory: heart, Sort order: 145
    case billedCap = "🧢" // Category: objects, Subcategory: clothing, Sort order: 1190
    case scarf = "🧣" // Category: objects, Subcategory: clothing, Sort order: 1158
    case gloves = "🧤" // Category: objects, Subcategory: clothing, Sort order: 1159
    case coat = "🧥" // Category: objects, Subcategory: clothing, Sort order: 1160
    case socks = "🧦" // Category: objects, Subcategory: clothing, Sort order: 1161
    case redGiftEnvelope = "🧧" // Category: activities, Subcategory: event, Sort order: 1080
    case firecracker = "🧨" // Category: activities, Subcategory: event, Sort order: 1069
    case jigsawPuzzlePiece = "🧩" // Category: activities, Subcategory: game, Sort order: 1130
    case testTube = "🧪" // Category: objects, Subcategory: science, Sort order: 1365
    case petriDish = "🧫" // Category: objects, Subcategory: science, Sort order: 1366
    case dnaDoubleHelix = "🧬" // Category: objects, Subcategory: science, Sort order: 1367
    case compass = "🧭" // Category: travelPlaces, Subcategory: place-map, Sort order: 853
    case abacus = "🧮" // Category: objects, Subcategory: computer, Sort order: 1245
    case fireExtinguisher = "🧯" // Category: objects, Subcategory: household, Sort order: 1401
    case toolbox = "🧰" // Category: objects, Subcategory: tool, Sort order: 1361
    case brick = "🧱" // Category: travelPlaces, Subcategory: place-building, Sort order: 866
    case magnet = "🧲" // Category: objects, Subcategory: tool, Sort order: 1362
    case luggage = "🧳" // Category: travelPlaces, Subcategory: hotel, Sort order: 986
    case lotionBottle = "🧴" // Category: objects, Subcategory: household, Sort order: 1391
    case spoolOfThread = "🧵" // Category: activities, Subcategory: arts & crafts, Sort order: 1146
    case ballOfYarn = "🧶" // Category: activities, Subcategory: arts & crafts, Sort order: 1148
    case safetyPin = "🧷" // Category: objects, Subcategory: household, Sort order: 1392
    case teddyBear = "🧸" // Category: activities, Subcategory: game, Sort order: 1131
    case broom = "🧹" // Category: objects, Subcategory: household, Sort order: 1393
    case basket = "🧺" // Category: objects, Subcategory: household, Sort order: 1394
    case rollOfPaper = "🧻" // Category: objects, Subcategory: household, Sort order: 1395
    case barOfSoap = "🧼" // Category: objects, Subcategory: household, Sort order: 1397
    case sponge = "🧽" // Category: objects, Subcategory: household, Sort order: 1400
    case receipt = "🧾" // Category: objects, Subcategory: money, Sort order: 1287
    case nazarAmulet = "🧿" // Category: objects, Subcategory: other-object, Sort order: 1407
    case balletShoes = "🩰" // Category: objects, Subcategory: clothing, Sort order: 1183
    case onepieceSwimsuit = "🩱" // Category: objects, Subcategory: clothing, Sort order: 1165
    case briefs = "🩲" // Category: objects, Subcategory: clothing, Sort order: 1166
    case shorts = "🩳" // Category: objects, Subcategory: clothing, Sort order: 1167
    case thongSandal = "🩴" // Category: objects, Subcategory: clothing, Sort order: 1176
    case lightBlueHeart = "🩵" // Category: smileysEmotion, Subcategory: heart, Sort order: 149
    case greyHeart = "🩶" // Category: smileysEmotion, Subcategory: heart, Sort order: 153
    case pinkHeart = "🩷" // Category: smileysEmotion, Subcategory: heart, Sort order: 144
    case dropOfBlood = "🩸" // Category: objects, Subcategory: medical, Sort order: 1372
    case adhesiveBandage = "🩹" // Category: objects, Subcategory: medical, Sort order: 1374
    case stethoscope = "🩺" // Category: objects, Subcategory: medical, Sort order: 1376
    case xray = "🩻" // Category: objects, Subcategory: medical, Sort order: 1377
    case crutch = "🩼" // Category: objects, Subcategory: medical, Sort order: 1375
    case yoyo = "🪀" // Category: activities, Subcategory: game, Sort order: 1120
    case kite = "🪁" // Category: activities, Subcategory: game, Sort order: 1121
    case parachute = "🪂" // Category: travelPlaces, Subcategory: transport-air, Sort order: 976
    case boomerang = "🪃" // Category: objects, Subcategory: tool, Sort order: 1346
    case magicWand = "🪄" // Category: activities, Subcategory: game, Sort order: 1125
    case pinata = "🪅" // Category: activities, Subcategory: game, Sort order: 1132
    case nestingDolls = "🪆" // Category: activities, Subcategory: game, Sort order: 1134
    case maracas = "🪇" // Category: objects, Subcategory: musical-instrument, Sort order: 1224
    case flute = "🪈" // Category: objects, Subcategory: musical-instrument, Sort order: 1225
    case ringedPlanet = "🪐" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1034
    case chair = "🪑" // Category: objects, Subcategory: household, Sort order: 1384
    case razor = "🪒" // Category: objects, Subcategory: household, Sort order: 1390
    case axe = "🪓" // Category: objects, Subcategory: tool, Sort order: 1339
    case diyaLamp = "🪔" // Category: objects, Subcategory: light & video, Sort order: 1261
    case banjo = "🪕" // Category: objects, Subcategory: musical-instrument, Sort order: 1221
    case militaryHelmet = "🪖" // Category: objects, Subcategory: clothing, Sort order: 1191
    case accordion = "🪗" // Category: objects, Subcategory: musical-instrument, Sort order: 1216
    case longDrum = "🪘" // Category: objects, Subcategory: musical-instrument, Sort order: 1223
    case coin = "🪙" // Category: objects, Subcategory: money, Sort order: 1280
    case carpentrySaw = "🪚" // Category: objects, Subcategory: tool, Sort order: 1349
    case screwdriver = "🪛" // Category: objects, Subcategory: tool, Sort order: 1351
    case ladder = "🪜" // Category: objects, Subcategory: tool, Sort order: 1363
    case hook = "🪝" // Category: objects, Subcategory: tool, Sort order: 1360
    case mirror = "🪞" // Category: objects, Subcategory: household, Sort order: 1380
    case window = "🪟" // Category: objects, Subcategory: household, Sort order: 1381
    case plunger = "🪠" // Category: objects, Subcategory: household, Sort order: 1386
    case sewingNeedle = "🪡" // Category: activities, Subcategory: arts & crafts, Sort order: 1147
    case knot = "🪢" // Category: activities, Subcategory: arts & crafts, Sort order: 1149
    case bucket = "🪣" // Category: objects, Subcategory: household, Sort order: 1396
    case mouseTrap = "🪤" // Category: objects, Subcategory: household, Sort order: 1389
    case toothbrush = "🪥" // Category: objects, Subcategory: household, Sort order: 1399
    case headstone = "🪦" // Category: objects, Subcategory: other-object, Sort order: 1405
    case placard = "🪧" // Category: objects, Subcategory: other-object, Sort order: 1410
    case rock = "🪨" // Category: travelPlaces, Subcategory: place-building, Sort order: 867
    case mirrorBall = "🪩" // Category: activities, Subcategory: game, Sort order: 1133
    case identificationCard = "🪪" // Category: objects, Subcategory: other-object, Sort order: 1411
    case lowBattery = "🪫" // Category: objects, Subcategory: computer, Sort order: 1233
    case hamsa = "🪬" // Category: objects, Subcategory: other-object, Sort order: 1408
    case foldingHandFan = "🪭" // Category: objects, Subcategory: clothing, Sort order: 1170
    case hairPick = "🪮" // Category: objects, Subcategory: clothing, Sort order: 1185
    case khanda = "🪯" // Category: symbols, Subcategory: religion, Sort order: 1471
    case fly = "🪰" // Category: animalsNature, Subcategory: animal-bug, Sort order: 681
    case worm = "🪱" // Category: animalsNature, Subcategory: animal-bug, Sort order: 682
    case beetle = "🪲" // Category: animalsNature, Subcategory: animal-bug, Sort order: 673
    case cockroach = "🪳" // Category: animalsNature, Subcategory: animal-bug, Sort order: 676
    case pottedPlant = "🪴" // Category: animalsNature, Subcategory: plant-other, Sort order: 697
    case wood = "🪵" // Category: travelPlaces, Subcategory: place-building, Sort order: 868
    case feather = "🪶" // Category: animalsNature, Subcategory: animal-bird, Sort order: 639
    case lotus = "🪷" // Category: animalsNature, Subcategory: plant-flower, Sort order: 687
    case coral = "🪸" // Category: animalsNature, Subcategory: animal-marine, Sort order: 666
    case emptyNest = "🪹" // Category: animalsNature, Subcategory: plant-other, Sort order: 709
    case nestWithEggs = "🪺" // Category: animalsNature, Subcategory: plant-other, Sort order: 710
    case hyacinth = "🪻" // Category: animalsNature, Subcategory: plant-flower, Sort order: 695
    case jellyfish = "🪼" // Category: animalsNature, Subcategory: animal-marine, Sort order: 667
    case wing = "🪽" // Category: animalsNature, Subcategory: animal-bird, Sort order: 643
    case goose = "🪿" // Category: animalsNature, Subcategory: animal-bird, Sort order: 645
    case anatomicalHeart = "🫀" // Category: peopleBody, Subcategory: body-parts, Sort order: 221
    case lungs = "🫁" // Category: peopleBody, Subcategory: body-parts, Sort order: 222
    case peopleHugging = "🫂" // Category: peopleBody, Subcategory: person-symbol, Sort order: 547
    case pregnantMan = "🫃" // Category: peopleBody, Subcategory: person-role, Sort order: 364
    case pregnantPerson = "🫄" // Category: peopleBody, Subcategory: person-role, Sort order: 365
    case personWithCrown = "🫅" // Category: peopleBody, Subcategory: person-role, Sort order: 349
    case moose = "🫎" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 579
    case donkey = "🫏" // Category: animalsNature, Subcategory: animal-mammal, Sort order: 580
    case blueberries = "🫐" // Category: foodDrink, Subcategory: food-fruit, Sort order: 727
    case bellPepper = "🫑" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 738
    case olive = "🫒" // Category: foodDrink, Subcategory: food-fruit, Sort order: 730
    case flatbread = "🫓" // Category: foodDrink, Subcategory: food-prepared, Sort order: 753
    case tamale = "🫔" // Category: foodDrink, Subcategory: food-prepared, Sort order: 770
    case fondue = "🫕" // Category: foodDrink, Subcategory: food-prepared, Sort order: 777
    case teapot = "🫖" // Category: foodDrink, Subcategory: drink, Sort order: 823
    case pouringLiquid = "🫗" // Category: foodDrink, Subcategory: drink, Sort order: 834
    case beans = "🫘" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 745
    case jar = "🫙" // Category: foodDrink, Subcategory: dishware, Sort order: 845
    case gingerRoot = "🫚" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 747
    case peaPod = "🫛" // Category: foodDrink, Subcategory: food-vegetable, Sort order: 748
    case meltingFace = "🫠" // Category: smileysEmotion, Subcategory: face-smiling, Sort order: 11
    case salutingFace = "🫡" // Category: smileysEmotion, Subcategory: face-hand, Sort order: 36
    case faceWithOpenEyesAndHandOverMouth = "🫢" // Category: smileysEmotion, Subcategory: face-hand, Sort order: 32
    case faceWithPeekingEye = "🫣" // Category: smileysEmotion, Subcategory: face-hand, Sort order: 33
    case faceWithDiagonalMouth = "🫤" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 77
    case dottedLineFace = "🫥" // Category: smileysEmotion, Subcategory: face-neutral-skeptical, Sort order: 42
    case bitingLip = "🫦" // Category: peopleBody, Subcategory: body-parts, Sort order: 229
    case bubbles = "🫧" // Category: objects, Subcategory: household, Sort order: 1398
    case shakingFace = "🫨" // Category: smileysEmotion, Subcategory: face-neutral-skeptical, Sort order: 50
    case handWithIndexFingerAndThumbCrossed = "🫰" // Category: peopleBody, Subcategory: hand-fingers-partial, Sort order: 185
    case rightwardsHand = "🫱" // Category: peopleBody, Subcategory: hand-fingers-open, Sort order: 174
    case leftwardsHand = "🫲" // Category: peopleBody, Subcategory: hand-fingers-open, Sort order: 175
    case palmDownHand = "🫳" // Category: peopleBody, Subcategory: hand-fingers-open, Sort order: 176
    case palmUpHand = "🫴" // Category: peopleBody, Subcategory: hand-fingers-open, Sort order: 177
    case indexPointingAtTheViewer = "🫵" // Category: peopleBody, Subcategory: hand-single-finger, Sort order: 195
    case heartHands = "🫶" // Category: peopleBody, Subcategory: hands, Sort order: 204
    case leftwardsPushingHand = "🫷" // Category: peopleBody, Subcategory: hand-fingers-open, Sort order: 178
    case rightwardsPushingHand = "🫸" // Category: peopleBody, Subcategory: hand-fingers-open, Sort order: 179
    case doubleExclamationMark = "‼️" // Category: symbols, Subcategory: punctuation, Sort order: 1519
    case exclamationQuestionMark = "⁉️" // Category: symbols, Subcategory: punctuation, Sort order: 1520
    case tradeMarkSign = "™️" // Category: symbols, Subcategory: other-symbol, Sort order: 1548
    case informationSource = "ℹ️" // Category: symbols, Subcategory: alphanum, Sort order: 1573
    case leftRightArrow = "↔️" // Category: symbols, Subcategory: arrow, Sort order: 1447
    case upDownArrow = "↕️" // Category: symbols, Subcategory: arrow, Sort order: 1446
    case northWestArrow = "↖️" // Category: symbols, Subcategory: arrow, Sort order: 1445
    case northEastArrow = "↗️" // Category: symbols, Subcategory: arrow, Sort order: 1439
    case southEastArrow = "↘️" // Category: symbols, Subcategory: arrow, Sort order: 1441
    case southWestArrow = "↙️" // Category: symbols, Subcategory: arrow, Sort order: 1443
    case leftwardsArrowWithHook = "↩️" // Category: symbols, Subcategory: arrow, Sort order: 1448
    case rightwardsArrowWithHook = "↪️" // Category: symbols, Subcategory: arrow, Sort order: 1449
    case watch = "⌚" // Category: travelPlaces, Subcategory: time, Sort order: 989
    case hourglass = "⌛" // Category: travelPlaces, Subcategory: time, Sort order: 987
    case keyboard = "⌨️" // Category: objects, Subcategory: computer, Sort order: 1238
    case ejectButton = "⏏️" // Category: symbols, Subcategory: av-symbol, Sort order: 1502
    case blackRightpointingDoubleTriangle = "⏩" // Category: symbols, Subcategory: av-symbol, Sort order: 1489
    case blackLeftpointingDoubleTriangle = "⏪" // Category: symbols, Subcategory: av-symbol, Sort order: 1493
    case blackUppointingDoubleTriangle = "⏫" // Category: symbols, Subcategory: av-symbol, Sort order: 1496
    case blackDownpointingDoubleTriangle = "⏬" // Category: symbols, Subcategory: av-symbol, Sort order: 1498
    case nextTrackButton = "⏭️" // Category: symbols, Subcategory: av-symbol, Sort order: 1490
    case lastTrackButton = "⏮️" // Category: symbols, Subcategory: av-symbol, Sort order: 1494
    case playOrPauseButton = "⏯️" // Category: symbols, Subcategory: av-symbol, Sort order: 1491
    case alarmClock = "⏰" // Category: travelPlaces, Subcategory: time, Sort order: 990
    case stopwatch = "⏱️" // Category: travelPlaces, Subcategory: time, Sort order: 991
    case timerClock = "⏲️" // Category: travelPlaces, Subcategory: time, Sort order: 992
    case hourglassWithFlowingSand = "⏳" // Category: travelPlaces, Subcategory: time, Sort order: 988
    case pauseButton = "⏸️" // Category: symbols, Subcategory: av-symbol, Sort order: 1499
    case stopButton = "⏹️" // Category: symbols, Subcategory: av-symbol, Sort order: 1500
    case recordButton = "⏺️" // Category: symbols, Subcategory: av-symbol, Sort order: 1501
    case circledLatinCapitalLetterM = "Ⓜ️" // Category: symbols, Subcategory: alphanum, Sort order: 1575
    case blackSmallSquare = "▪️" // Category: symbols, Subcategory: geometric, Sort order: 1623
    case whiteSmallSquare = "▫️" // Category: symbols, Subcategory: geometric, Sort order: 1624
    case blackRightpointingTriangle = "▶️" // Category: symbols, Subcategory: av-symbol, Sort order: 1488
    case blackLeftpointingTriangle = "◀️" // Category: symbols, Subcategory: av-symbol, Sort order: 1492
    case whiteMediumSquare = "◻️" // Category: symbols, Subcategory: geometric, Sort order: 1620
    case blackMediumSquare = "◼️" // Category: symbols, Subcategory: geometric, Sort order: 1619
    case whiteMediumSmallSquare = "◽" // Category: symbols, Subcategory: geometric, Sort order: 1622
    case blackMediumSmallSquare = "◾" // Category: symbols, Subcategory: geometric, Sort order: 1621
    case blackSunWithRays = "☀️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1031
    case cloud = "☁️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1039
    case umbrella = "☂️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1054
    case snowman = "☃️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1059
    case comet = "☄️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1061
    case blackTelephone = "☎️" // Category: objects, Subcategory: phone, Sort order: 1228
    case ballotBoxWithCheck = "☑️" // Category: symbols, Subcategory: other-symbol, Sort order: 1536
    case umbrellaWithRainDrops = "☔" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1055
    case hotBeverage = "☕" // Category: foodDrink, Subcategory: drink, Sort order: 822
    case shamrock = "☘️" // Category: animalsNature, Subcategory: plant-other, Sort order: 704
    case whiteUpPointingIndex = "☝️" // Category: peopleBody, Subcategory: hand-single-finger, Sort order: 194
    case skullAndCrossbones = "☠️" // Category: smileysEmotion, Subcategory: face-negative, Sort order: 109
    case radioactive = "☢️" // Category: symbols, Subcategory: warning, Sort order: 1436
    case biohazard = "☣️" // Category: symbols, Subcategory: warning, Sort order: 1437
    case orthodoxCross = "☦️" // Category: symbols, Subcategory: religion, Sort order: 1466
    case starAndCrescent = "☪️" // Category: symbols, Subcategory: religion, Sort order: 1467
    case peaceSymbol = "☮️" // Category: symbols, Subcategory: religion, Sort order: 1468
    case yinYang = "☯️" // Category: symbols, Subcategory: religion, Sort order: 1464
    case wheelOfDharma = "☸️" // Category: symbols, Subcategory: religion, Sort order: 1463
    case frowningFace = "☹️" // Category: smileysEmotion, Subcategory: face-concerned, Sort order: 80
    case whiteSmilingFace = "☺️" // Category: smileysEmotion, Subcategory: face-affection, Sort order: 20
    case femaleSign = "♀️" // Category: symbols, Subcategory: gender, Sort order: 1510
    case maleSign = "♂️" // Category: symbols, Subcategory: gender, Sort order: 1511
    case aries = "♈" // Category: symbols, Subcategory: zodiac, Sort order: 1472
    case taurus = "♉" // Category: symbols, Subcategory: zodiac, Sort order: 1473
    case gemini = "♊" // Category: symbols, Subcategory: zodiac, Sort order: 1474
    case cancer = "♋" // Category: symbols, Subcategory: zodiac, Sort order: 1475
    case leo = "♌" // Category: symbols, Subcategory: zodiac, Sort order: 1476
    case virgo = "♍" // Category: symbols, Subcategory: zodiac, Sort order: 1477
    case libra = "♎" // Category: symbols, Subcategory: zodiac, Sort order: 1478
    case scorpius = "♏" // Category: symbols, Subcategory: zodiac, Sort order: 1479
    case sagittarius = "♐" // Category: symbols, Subcategory: zodiac, Sort order: 1480
    case capricorn = "♑" // Category: symbols, Subcategory: zodiac, Sort order: 1481
    case aquarius = "♒" // Category: symbols, Subcategory: zodiac, Sort order: 1482
    case pisces = "♓" // Category: symbols, Subcategory: zodiac, Sort order: 1483
    case chessPawn = "♟️" // Category: activities, Subcategory: game, Sort order: 1139
    case blackSpadeSuit = "♠️" // Category: activities, Subcategory: game, Sort order: 1135
    case blackClubSuit = "♣️" // Category: activities, Subcategory: game, Sort order: 1138
    case blackHeartSuit = "♥️" // Category: activities, Subcategory: game, Sort order: 1136
    case blackDiamondSuit = "♦️" // Category: activities, Subcategory: game, Sort order: 1137
    case hotSprings = "♨️" // Category: travelPlaces, Subcategory: place-other, Sort order: 906
    case blackUniversalRecyclingSymbol = "♻️" // Category: symbols, Subcategory: other-symbol, Sort order: 1529
    case infinity = "♾️" // Category: symbols, Subcategory: math, Sort order: 1518
    case wheelchairSymbol = "♿" // Category: symbols, Subcategory: transport-sign, Sort order: 1415
    case hammerAndPick = "⚒️" // Category: objects, Subcategory: tool, Sort order: 1341
    case anchor = "⚓" // Category: travelPlaces, Subcategory: transport-water, Sort order: 963
    case crossedSwords = "⚔️" // Category: objects, Subcategory: tool, Sort order: 1344
    case medicalSymbol = "⚕️" // Category: symbols, Subcategory: other-symbol, Sort order: 1528
    case balanceScale = "⚖️" // Category: objects, Subcategory: tool, Sort order: 1355
    case alembic = "⚗️" // Category: objects, Subcategory: science, Sort order: 1364
    case gear = "⚙️" // Category: objects, Subcategory: tool, Sort order: 1353
    case atomSymbol = "⚛️" // Category: symbols, Subcategory: religion, Sort order: 1460
    case fleurdelis = "⚜️" // Category: symbols, Subcategory: other-symbol, Sort order: 1530
    case warningSign = "⚠️" // Category: symbols, Subcategory: warning, Sort order: 1425
    case highVoltageSign = "⚡" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1057
    case transgenderSymbol = "⚧️" // Category: symbols, Subcategory: gender, Sort order: 1512
    case mediumWhiteCircle = "⚪" // Category: symbols, Subcategory: geometric, Sort order: 1609
    case mediumBlackCircle = "⚫" // Category: symbols, Subcategory: geometric, Sort order: 1608
    case coffin = "⚰️" // Category: objects, Subcategory: other-object, Sort order: 1404
    case funeralUrn = "⚱️" // Category: objects, Subcategory: other-object, Sort order: 1406
    case soccerBall = "⚽" // Category: activities, Subcategory: sport, Sort order: 1092
    case baseball = "⚾" // Category: activities, Subcategory: sport, Sort order: 1093
    case snowmanWithoutSnow = "⛄" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1060
    case sunBehindCloud = "⛅" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1040
    case cloudWithLightningAndRain = "⛈️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1041
    case ophiuchus = "⛎" // Category: symbols, Subcategory: zodiac, Sort order: 1484
    case pick = "⛏️" // Category: objects, Subcategory: tool, Sort order: 1340
    case rescueWorkersHelmet = "⛑️" // Category: objects, Subcategory: clothing, Sort order: 1192
    case brokenChain = "⛓️‍💥" // Category: objects, Subcategory: tool, Sort order: 1358
    case chains = "⛓️" // Category: objects, Subcategory: tool, Sort order: 1359
    case noEntry = "⛔" // Category: symbols, Subcategory: warning, Sort order: 1427
    case shintoShrine = "⛩️" // Category: travelPlaces, Subcategory: place-religious, Sort order: 894
    case church = "⛪" // Category: travelPlaces, Subcategory: place-religious, Sort order: 890
    case mountain = "⛰️" // Category: travelPlaces, Subcategory: place-geographic, Sort order: 855
    case umbrellaOnGround = "⛱️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1056
    case fountain = "⛲" // Category: travelPlaces, Subcategory: place-other, Sort order: 896
    case flagInHole = "⛳" // Category: activities, Subcategory: sport, Sort order: 1111
    case ferry = "⛴️" // Category: travelPlaces, Subcategory: transport-water, Sort order: 969
    case sailboat = "⛵" // Category: travelPlaces, Subcategory: transport-water, Sort order: 965
    case skier = "⛷️" // Category: peopleBody, Subcategory: person-sport, Sort order: 461
    case iceSkate = "⛸️" // Category: activities, Subcategory: sport, Sort order: 1112
    case womanBouncingBall = "⛹️‍♀️" // Category: peopleBody, Subcategory: person-sport, Sort order: 477
    case manBouncingBall = "⛹️‍♂️" // Category: peopleBody, Subcategory: person-sport, Sort order: 476
    case personBouncingBall = "⛹️" // Category: peopleBody, Subcategory: person-sport, Sort order: 475
    case tent = "⛺" // Category: travelPlaces, Subcategory: place-other, Sort order: 897
    case fuelPump = "⛽" // Category: travelPlaces, Subcategory: transport-ground, Sort order: 956
    case blackScissors = "✂️" // Category: objects, Subcategory: office, Sort order: 1328
    case whiteHeavyCheckMark = "✅" // Category: symbols, Subcategory: other-symbol, Sort order: 1535
    case airplane = "✈️" // Category: travelPlaces, Subcategory: transport-air, Sort order: 972
    case envelope = "✉️" // Category: objects, Subcategory: mail, Sort order: 1289
    case raisedFist = "✊" // Category: peopleBody, Subcategory: hand-fingers-closed, Sort order: 198
    case raisedHand = "✋" // Category: peopleBody, Subcategory: hand-fingers-open, Sort order: 172
    case victoryHand = "✌️" // Category: peopleBody, Subcategory: hand-fingers-partial, Sort order: 183
    case writingHand = "✍️" // Category: peopleBody, Subcategory: hand-prop, Sort order: 209
    case pencil = "✏️" // Category: objects, Subcategory: writing, Sort order: 1302
    case blackNib = "✒️" // Category: objects, Subcategory: writing, Sort order: 1303
    case heavyCheckMark = "✔️" // Category: symbols, Subcategory: other-symbol, Sort order: 1537
    case heavyMultiplicationX = "✖️" // Category: symbols, Subcategory: math, Sort order: 1513
    case latinCross = "✝️" // Category: symbols, Subcategory: religion, Sort order: 1465
    case starOfDavid = "✡️" // Category: symbols, Subcategory: religion, Sort order: 1462
    case sparkles = "✨" // Category: activities, Subcategory: event, Sort order: 1070
    case eightSpokedAsterisk = "✳️" // Category: symbols, Subcategory: other-symbol, Sort order: 1543
    case eightPointedBlackStar = "✴️" // Category: symbols, Subcategory: other-symbol, Sort order: 1544
    case snowflake = "❄️" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1058
    case sparkle = "❇️" // Category: symbols, Subcategory: other-symbol, Sort order: 1545
    case crossMark = "❌" // Category: symbols, Subcategory: other-symbol, Sort order: 1538
    case negativeSquaredCrossMark = "❎" // Category: symbols, Subcategory: other-symbol, Sort order: 1539
    case blackQuestionMarkOrnament = "❓" // Category: symbols, Subcategory: punctuation, Sort order: 1521
    case whiteQuestionMarkOrnament = "❔" // Category: symbols, Subcategory: punctuation, Sort order: 1522
    case whiteExclamationMarkOrnament = "❕" // Category: symbols, Subcategory: punctuation, Sort order: 1523
    case heavyExclamationMarkSymbol = "❗" // Category: symbols, Subcategory: punctuation, Sort order: 1524
    case heartExclamation = "❣️" // Category: smileysEmotion, Subcategory: heart, Sort order: 139
    case heartOnFire = "❤️‍🔥" // Category: smileysEmotion, Subcategory: heart, Sort order: 141
    case mendingHeart = "❤️‍🩹" // Category: smileysEmotion, Subcategory: heart, Sort order: 142
    case heavyBlackHeart = "❤️" // Category: smileysEmotion, Subcategory: heart, Sort order: 143
    case heavyPlusSign = "➕" // Category: symbols, Subcategory: math, Sort order: 1514
    case heavyMinusSign = "➖" // Category: symbols, Subcategory: math, Sort order: 1515
    case heavyDivisionSign = "➗" // Category: symbols, Subcategory: math, Sort order: 1516
    case blackRightwardsArrow = "➡️" // Category: symbols, Subcategory: arrow, Sort order: 1440
    case curlyLoop = "➰" // Category: symbols, Subcategory: other-symbol, Sort order: 1540
    case doubleCurlyLoop = "➿" // Category: symbols, Subcategory: other-symbol, Sort order: 1541
    case arrowPointingRightwardsThenCurvingUpwards = "⤴️" // Category: symbols, Subcategory: arrow, Sort order: 1450
    case arrowPointingRightwardsThenCurvingDownwards = "⤵️" // Category: symbols, Subcategory: arrow, Sort order: 1451
    case leftwardsBlackArrow = "⬅️" // Category: symbols, Subcategory: arrow, Sort order: 1444
    case upwardsBlackArrow = "⬆️" // Category: symbols, Subcategory: arrow, Sort order: 1438
    case downwardsBlackArrow = "⬇️" // Category: symbols, Subcategory: arrow, Sort order: 1442
    case blackLargeSquare = "⬛" // Category: symbols, Subcategory: geometric, Sort order: 1617
    case whiteLargeSquare = "⬜" // Category: symbols, Subcategory: geometric, Sort order: 1618
    case whiteMediumStar = "⭐" // Category: travelPlaces, Subcategory: sky & weather, Sort order: 1035
    case heavyLargeCircle = "⭕" // Category: symbols, Subcategory: other-symbol, Sort order: 1534
    case wavyDash = "〰️" // Category: symbols, Subcategory: punctuation, Sort order: 1525
    case partAlternationMark = "〽️" // Category: symbols, Subcategory: other-symbol, Sort order: 1542
    case circledIdeographCongratulation = "㊗️" // Category: symbols, Subcategory: alphanum, Sort order: 1597
    case circledIdeographSecret = "㊙️" // Category: symbols, Subcategory: alphanum, Sort order: 1598
}

public enum EmojiCategory {
    case activities
    case animalsNature
    case component
    case flags
    case foodDrink
    case objects
    case peopleBody
    case smileysEmotion
    case symbols
    case travelPlaces

    var emojis: [Emoji] {
        switch self {
        case .symbols:
            return [.hashKey, .keycap, .keycap0, .keycap1, .keycap2, .keycap3, .keycap4, .keycap5, .keycap6, .keycap7, .keycap8, .keycap9, .copyrightSign, .registeredSign, .negativeSquaredLatinCapitalLetterA, .negativeSquaredLatinCapitalLetterB, .negativeSquaredLatinCapitalLetterO, .negativeSquaredLatinCapitalLetterP, .negativeSquaredAb, .squaredCl, .squaredCool, .squaredFree, .squaredId, .squaredNew, .squaredNg, .squaredOk, .squaredSos, .squaredUpWithExclamationMark, .squaredVs, .squaredKatakanaKoko, .squaredKatakanaSa, .squaredCjkUnifiedIdeograph7121, .squaredCjkUnifiedIdeograph6307, .squaredCjkUnifiedIdeograph7981, .squaredCjkUnifiedIdeograph7A7A, .squaredCjkUnifiedIdeograph5408, .squaredCjkUnifiedIdeograph6E80, .squaredCjkUnifiedIdeograph6709, .squaredCjkUnifiedIdeograph6708, .squaredCjkUnifiedIdeograph7533, .squaredCjkUnifiedIdeograph5272, .squaredCjkUnifiedIdeograph55B6, .circledIdeographAdvantage, .circledIdeographAccept, .cinema, .automatedTellerMachine, .diamondShapeWithADotInside, .currencyExchange, .heavyDollarSign, .nameBadge, .vibrationMode, .mobilePhoneOff, .noMobilePhones, .antennaWithBars, .twistedRightwardsArrows, .clockwiseRightwardsAndLeftwardsOpenCircleArrows, .clockwiseRightwardsAndLeftwardsOpenCircleArrowsWithCircledOneOverlay, .clockwiseDownwardsAndUpwardsOpenCircleArrows, .anticlockwiseDownwardsAndUpwardsOpenCircleArrows, .lowBrightnessSymbol, .highBrightnessSymbol, .radioButton, .backWithLeftwardsArrowAbove, .endWithLeftwardsArrowAbove, .onWithExclamationMarkWithLeftRightArrowAbove, .soonWithRightwardsArrowAbove, .topWithUpwardsArrowAbove, .noOneUnderEighteenSymbol, .keycapTen, .inputSymbolForLatinCapitalLetters, .inputSymbolForLatinSmallLetters, .inputSymbolForNumbers, .inputSymbolForSymbols, .inputSymbolForLatinLetters, .sixPointedStarWithMiddleDot, .japaneseSymbolForBeginner, .tridentEmblem, .blackSquareButton, .whiteSquareButton, .largeRedCircle, .largeBlueCircle, .largeOrangeDiamond, .largeBlueDiamond, .smallOrangeDiamond, .smallBlueDiamond, .uppointingRedTriangle, .downpointingRedTriangle, .uppointingSmallRedTriangle, .downpointingSmallRedTriangle, .om, .menorahWithNineBranches, .noEntrySign, .noSmokingSymbol, .putLitterInItsPlaceSymbol, .doNotLitterSymbol, .potableWaterSymbol, .nonpotableWaterSymbol, .noBicycles, .noPedestrians, .childrenCrossing, .mensSymbol, .womensSymbol, .restroom, .babySymbol, .waterCloset, .passportControl, .customs, .baggageClaim, .leftLuggage, .placeOfWorship, .wireless, .largeOrangeCircle, .largeYellowCircle, .largeGreenCircle, .largePurpleCircle, .largeBrownCircle, .largeRedSquare, .largeBlueSquare, .largeOrangeSquare, .largeYellowSquare, .largeGreenSquare, .largePurpleSquare, .largeBrownSquare, .heavyEqualsSign, .khanda, .doubleExclamationMark, .exclamationQuestionMark, .tradeMarkSign, .informationSource, .leftRightArrow, .upDownArrow, .northWestArrow, .northEastArrow, .southEastArrow, .southWestArrow, .leftwardsArrowWithHook, .rightwardsArrowWithHook, .ejectButton, .blackRightpointingDoubleTriangle, .blackLeftpointingDoubleTriangle, .blackUppointingDoubleTriangle, .blackDownpointingDoubleTriangle, .nextTrackButton, .lastTrackButton, .playOrPauseButton, .pauseButton, .stopButton, .recordButton, .circledLatinCapitalLetterM, .blackSmallSquare, .whiteSmallSquare, .blackRightpointingTriangle, .blackLeftpointingTriangle, .whiteMediumSquare, .blackMediumSquare, .whiteMediumSmallSquare, .blackMediumSmallSquare, .ballotBoxWithCheck, .radioactive, .biohazard, .orthodoxCross, .starAndCrescent, .peaceSymbol, .yinYang, .wheelOfDharma, .femaleSign, .maleSign, .aries, .taurus, .gemini, .cancer, .leo, .virgo, .libra, .scorpius, .sagittarius, .capricorn, .aquarius, .pisces, .blackUniversalRecyclingSymbol, .infinity, .wheelchairSymbol, .medicalSymbol, .atomSymbol, .fleurdelis, .warningSign, .transgenderSymbol, .mediumWhiteCircle, .mediumBlackCircle, .ophiuchus, .noEntry, .whiteHeavyCheckMark, .heavyCheckMark, .heavyMultiplicationX, .latinCross, .starOfDavid, .eightSpokedAsterisk, .eightPointedBlackStar, .sparkle, .crossMark, .negativeSquaredCrossMark, .blackQuestionMarkOrnament, .whiteQuestionMarkOrnament, .whiteExclamationMarkOrnament, .heavyExclamationMarkSymbol, .heavyPlusSign, .heavyMinusSign, .heavyDivisionSign, .blackRightwardsArrow, .curlyLoop, .doubleCurlyLoop, .arrowPointingRightwardsThenCurvingUpwards, .arrowPointingRightwardsThenCurvingDownwards, .leftwardsBlackArrow, .upwardsBlackArrow, .downwardsBlackArrow, .blackLargeSquare, .whiteLargeSquare, .heavyLargeCircle, .wavyDash, .partAlternationMark, .circledIdeographCongratulation, .circledIdeographSecret]
        case .activities:
            return [.mahjongTileRedDragon, .playingCardBlackJoker, .ribbon, .wrappedPresent, .jackolantern, .christmasTree, .fireworks, .fireworkSparkler, .balloon, .partyPopper, .confettiBall, .tanabataTree, .pineDecoration, .japaneseDolls, .carpStreamer, .windChime, .moonViewingCeremony, .militaryMedal, .reminderRibbon, .admissionTickets, .fishingPoleAndFish, .artistPalette, .ticket, .performingArts, .videoGame, .directHit, .slotMachine, .billiards, .gameDie, .bowling, .flowerPlayingCards, .runningShirtWithSash, .tennisRacquetAndBall, .skiAndSkiBoot, .basketballAndHoop, .sportsMedal, .trophy, .americanFootball, .rugbyFootball, .cricketBatAndBall, .volleyball, .fieldHockeyStickAndBall, .iceHockeyStickAndPuck, .tableTennisPaddleAndBall, .badmintonRacquetAndShuttlecock, .pistol, .crystalBall, .joystick, .framedPicture, .sled, .divingMask, .goalNet, .firstPlaceMedal, .secondPlaceMedal, .thirdPlaceMedal, .boxingGlove, .martialArtsUniform, .curlingStone, .lacrosseStickAndBall, .softball, .flyingDisc, .redGiftEnvelope, .firecracker, .jigsawPuzzlePiece, .spoolOfThread, .ballOfYarn, .teddyBear, .yoyo, .kite, .magicWand, .pinata, .nestingDolls, .sewingNeedle, .knot, .mirrorBall, .chessPawn, .blackSpadeSuit, .blackClubSuit, .blackHeartSuit, .blackDiamondSuit, .soccerBall, .baseball, .flagInHole, .iceSkate, .sparkles]
        case .flags:
            return [.ascensionIslandFlag, .andorraFlag, .unitedArabEmiratesFlag, .afghanistanFlag, .antiguaBarbudaFlag, .anguillaFlag, .albaniaFlag, .armeniaFlag, .angolaFlag, .antarcticaFlag, .argentinaFlag, .americanSamoaFlag, .austriaFlag, .australiaFlag, .arubaFlag, .ålandIslandsFlag, .azerbaijanFlag, .bosniaHerzegovinaFlag, .barbadosFlag, .bangladeshFlag, .belgiumFlag, .burkinaFasoFlag, .bulgariaFlag, .bahrainFlag, .burundiFlag, .beninFlag, .stBarthélemyFlag, .bermudaFlag, .bruneiFlag, .boliviaFlag, .caribbeanNetherlandsFlag, .brazilFlag, .bahamasFlag, .bhutanFlag, .bouvetIslandFlag, .botswanaFlag, .belarusFlag, .belizeFlag, .canadaFlag, .cocosKeelingIslandsFlag, .congoKinshasaFlag, .centralAfricanRepublicFlag, .congoBrazzavilleFlag, .switzerlandFlag, .côteDivoireFlag, .cookIslandsFlag, .chileFlag, .cameroonFlag, .chinaFlag, .colombiaFlag, .clippertonIslandFlag, .costaRicaFlag, .cubaFlag, .capeVerdeFlag, .curaçaoFlag, .christmasIslandFlag, .cyprusFlag, .czechiaFlag, .germanyFlag, .diegoGarciaFlag, .djiboutiFlag, .denmarkFlag, .dominicaFlag, .dominicanRepublicFlag, .algeriaFlag, .ceutaMelillaFlag, .ecuadorFlag, .estoniaFlag, .egyptFlag, .westernSaharaFlag, .eritreaFlag, .spainFlag, .ethiopiaFlag, .europeanUnionFlag, .finlandFlag, .fijiFlag, .falklandIslandsFlag, .micronesiaFlag, .faroeIslandsFlag, .franceFlag, .gabonFlag, .unitedKingdomFlag, .grenadaFlag, .georgiaFlag, .frenchGuianaFlag, .guernseyFlag, .ghanaFlag, .gibraltarFlag, .greenlandFlag, .gambiaFlag, .guineaFlag, .guadeloupeFlag, .equatorialGuineaFlag, .greeceFlag, .southGeorgiaSouthSandwichIslandsFlag, .guatemalaFlag, .guamFlag, .guineabissauFlag, .guyanaFlag, .hongKongSarChinaFlag, .heardMcdonaldIslandsFlag, .hondurasFlag, .croatiaFlag, .haitiFlag, .hungaryFlag, .canaryIslandsFlag, .indonesiaFlag, .irelandFlag, .israelFlag, .isleOfManFlag, .indiaFlag, .britishIndianOceanTerritoryFlag, .iraqFlag, .iranFlag, .icelandFlag, .italyFlag, .jerseyFlag, .jamaicaFlag, .jordanFlag, .japanFlag, .kenyaFlag, .kyrgyzstanFlag, .cambodiaFlag, .kiribatiFlag, .comorosFlag, .stKittsNevisFlag, .northKoreaFlag, .southKoreaFlag, .kuwaitFlag, .caymanIslandsFlag, .kazakhstanFlag, .laosFlag, .lebanonFlag, .stLuciaFlag, .liechtensteinFlag, .sriLankaFlag, .liberiaFlag, .lesothoFlag, .lithuaniaFlag, .luxembourgFlag, .latviaFlag, .libyaFlag, .moroccoFlag, .monacoFlag, .moldovaFlag, .montenegroFlag, .stMartinFlag, .madagascarFlag, .marshallIslandsFlag, .northMacedoniaFlag, .maliFlag, .myanmarBurmaFlag, .mongoliaFlag, .macaoSarChinaFlag, .northernMarianaIslandsFlag, .martiniqueFlag, .mauritaniaFlag, .montserratFlag, .maltaFlag, .mauritiusFlag, .maldivesFlag, .malawiFlag, .mexicoFlag, .malaysiaFlag, .mozambiqueFlag, .namibiaFlag, .newCaledoniaFlag, .nigerFlag, .norfolkIslandFlag, .nigeriaFlag, .nicaraguaFlag, .netherlandsFlag, .norwayFlag, .nepalFlag, .nauruFlag, .niueFlag, .newZealandFlag, .omanFlag, .panamaFlag, .peruFlag, .frenchPolynesiaFlag, .papuaNewGuineaFlag, .philippinesFlag, .pakistanFlag, .polandFlag, .stPierreMiquelonFlag, .pitcairnIslandsFlag, .puertoRicoFlag, .palestinianTerritoriesFlag, .portugalFlag, .palauFlag, .paraguayFlag, .qatarFlag, .réunionFlag, .romaniaFlag, .serbiaFlag, .russiaFlag, .rwandaFlag, .saudiArabiaFlag, .solomonIslandsFlag, .seychellesFlag, .sudanFlag, .swedenFlag, .singaporeFlag, .stHelenaFlag, .sloveniaFlag, .svalbardJanMayenFlag, .slovakiaFlag, .sierraLeoneFlag, .sanMarinoFlag, .senegalFlag, .somaliaFlag, .surinameFlag, .southSudanFlag, .sãoToméPríncipeFlag, .elSalvadorFlag, .sintMaartenFlag, .syriaFlag, .eswatiniFlag, .tristanDaCunhaFlag, .turksCaicosIslandsFlag, .chadFlag, .frenchSouthernTerritoriesFlag, .togoFlag, .thailandFlag, .tajikistanFlag, .tokelauFlag, .timorlesteFlag, .turkmenistanFlag, .tunisiaFlag, .tongaFlag, .türkiyeFlag, .trinidadTobagoFlag, .tuvaluFlag, .taiwanFlag, .tanzaniaFlag, .ukraineFlag, .ugandaFlag, .usOutlyingIslandsFlag, .unitedNationsFlag, .unitedStatesFlag, .uruguayFlag, .uzbekistanFlag, .vaticanCityFlag, .stVincentGrenadinesFlag, .venezuelaFlag, .britishVirginIslandsFlag, .usVirginIslandsFlag, .vietnamFlag, .vanuatuFlag, .wallisFutunaFlag, .samoaFlag, .kosovoFlag, .yemenFlag, .mayotteFlag, .southAfricaFlag, .zambiaFlag, .zimbabweFlag, .crossedFlags, .chequeredFlag, .rainbowFlag, .transgenderFlag, .whiteFlag, .pirateFlag, .englandFlag, .scotlandFlag, .walesFlag, .wavingBlackFlag, .triangularFlagOnPost]
        case .travelPlaces:
            return [.cyclone, .foggy, .closedUmbrella, .nightWithStars, .sunriseOverMountains, .sunrise, .cityscapeAtDusk, .sunsetOverBuildings, .rainbow, .bridgeAtNight, .waterWave, .volcano, .milkyWay, .earthGlobeEuropeafrica, .earthGlobeAmericas, .earthGlobeAsiaaustralia, .globeWithMeridians, .newMoonSymbol, .waxingCrescentMoonSymbol, .firstQuarterMoonSymbol, .waxingGibbousMoonSymbol, .fullMoonSymbol, .waningGibbousMoonSymbol, .lastQuarterMoonSymbol, .waningCrescentMoonSymbol, .crescentMoon, .newMoonWithFace, .firstQuarterMoonWithFace, .lastQuarterMoonWithFace, .fullMoonWithFace, .sunWithFace, .glowingStar, .shootingStar, .thermometer, .sunBehindSmallCloud, .sunBehindLargeCloud, .sunBehindRainCloud, .cloudWithRain, .cloudWithSnow, .cloudWithLightning, .tornado, .fog, .windFace, .carouselHorse, .ferrisWheel, .rollerCoaster, .circusTent, .motorcycle, .racingCar, .snowcappedMountain, .camping, .beachWithUmbrella, .buildingConstruction, .houses, .cityscape, .derelictHouse, .classicalBuilding, .desert, .desertIsland, .nationalPark, .stadium, .houseBuilding, .houseWithGarden, .officeBuilding, .japanesePostOffice, .europeanPostOffice, .hospital, .bank, .hotel, .loveHotel, .convenienceStore, .school, .departmentStore, .factory, .japaneseCastle, .europeanCastle, .barberPole, .wedding, .droplet, .seat, .fire, .kaaba, .mosque, .synagogue, .clockFaceOneOclock, .clockFaceTwoOclock, .clockFaceThreeOclock, .clockFaceFourOclock, .clockFaceFiveOclock, .clockFaceSixOclock, .clockFaceSevenOclock, .clockFaceEightOclock, .clockFaceNineOclock, .clockFaceTenOclock, .clockFaceElevenOclock, .clockFaceTwelveOclock, .clockFaceOnethirty, .clockFaceTwothirty, .clockFaceThreethirty, .clockFaceFourthirty, .clockFaceFivethirty, .clockFaceSixthirty, .clockFaceSeventhirty, .clockFaceEightthirty, .clockFaceNinethirty, .clockFaceTenthirty, .clockFaceEleventhirty, .clockFaceTwelvethirty, .mantelpieceClock, .worldMap, .mountFuji, .tokyoTower, .statueOfLiberty, .silhouetteOfJapan, .rocket, .helicopter, .steamLocomotive, .railwayCar, .highspeedTrain, .highspeedTrainWithBulletNose, .train, .metro, .lightRail, .station, .tram, .tramCar, .bus, .oncomingBus, .trolleybus, .busStop, .minibus, .ambulance, .fireEngine, .policeCar, .oncomingPoliceCar, .taxi, .oncomingTaxi, .automobile, .oncomingAutomobile, .recreationalVehicle, .deliveryTruck, .articulatedLorry, .tractor, .monorail, .mountainRailway, .suspensionRailway, .mountainCableway, .aerialTramway, .ship, .speedboat, .horizontalTrafficLight, .verticalTrafficLight, .constructionSign, .policeCarsRevolvingLight, .bicycle, .bellhopBell, .octagonalSign, .hinduTemple, .hut, .playgroundSlide, .wheel, .ringBuoy, .oilDrum, .motorway, .railwayTrack, .motorBoat, .smallAirplane, .airplaneDeparture, .airplaneArriving, .satellite, .passengerShip, .scooter, .motorScooter, .canoe, .flyingSaucer, .skateboard, .autoRickshaw, .pickupTruck, .rollerSkate, .motorizedWheelchair, .manualWheelchair, .compass, .brick, .luggage, .parachute, .ringedPlanet, .rock, .wood, .watch, .hourglass, .alarmClock, .stopwatch, .timerClock, .hourglassWithFlowingSand, .blackSunWithRays, .cloud, .umbrella, .snowman, .comet, .umbrellaWithRainDrops, .hotSprings, .anchor, .highVoltageSign, .snowmanWithoutSnow, .sunBehindCloud, .cloudWithLightningAndRain, .shintoShrine, .church, .mountain, .umbrellaOnGround, .fountain, .ferry, .sailboat, .tent, .fuelPump, .airplane, .snowflake, .whiteMediumStar]
        case .foodDrink:
            return [.hotDog, .taco, .burrito, .chestnut, .hotPepper, .earOfMaize, .brownMushroom, .tomato, .aubergine, .grapes, .melon, .watermelon, .tangerine, .lime, .lemon, .banana, .pineapple, .redApple, .greenApple, .pear, .peach, .cherries, .strawberry, .hamburger, .sliceOfPizza, .meatOnBone, .poultryLeg, .riceCracker, .riceBall, .cookedRice, .curryAndRice, .steamingBowl, .spaghetti, .bread, .frenchFries, .roastedSweetPotato, .dango, .oden, .sushi, .friedShrimp, .fishCakeWithSwirlDesign, .softIceCream, .shavedIce, .iceCream, .doughnut, .cookie, .chocolateBar, .candy, .lollipop, .custard, .honeyPot, .shortcake, .bentoBox, .potOfFood, .cooking, .forkAndKnife, .teacupWithoutHandle, .sakeBottleAndCup, .wineGlass, .cocktailGlass, .tropicalDrink, .beerMug, .clinkingBeerMugs, .babyBottle, .forkAndKnifeWithPlate, .bottleWithPoppingCork, .popcorn, .birthdayCake, .amphora, .hocho, .clinkingGlasses, .tumblerGlass, .spoon, .croissant, .avocado, .cucumber, .bacon, .potato, .carrot, .baguetteBread, .greenSalad, .shallowPanOfFood, .stuffedFlatbread, .egg, .glassOfMilk, .peanuts, .kiwifruit, .pancakes, .dumpling, .fortuneCookie, .takeoutBox, .chopsticks, .bowlWithSpoon, .cupWithStraw, .coconut, .broccoli, .pie, .pretzel, .cutOfMeat, .sandwich, .cannedFood, .leafyGreen, .mango, .moonCake, .bagel, .crab, .shrimp, .squid, .lobster, .oyster, .cheeseWedge, .cupcake, .saltShaker, .beverageBox, .garlic, .onion, .falafel, .waffle, .butter, .mateDrink, .iceCube, .bubbleTea, .blueberries, .bellPepper, .olive, .flatbread, .tamale, .fondue, .teapot, .pouringLiquid, .beans, .jar, .gingerRoot, .peaPod, .hotBeverage]
        case .animalsNature:
            return [.seedling, .evergreenTree, .deciduousTree, .palmTree, .cactus, .tulip, .cherryBlossom, .rose, .hibiscus, .sunflower, .blossom, .earOfRice, .herb, .fourLeafClover, .mapleLeaf, .fallenLeaf, .leafFlutteringInWind, .mushroom, .rosette, .rat, .mouse, .ox, .waterBuffalo, .cow, .tiger, .leopard, .rabbit, .blackCat, .cat, .dragon, .crocodile, .whale, .snail, .snake, .horse, .ram, .goat, .sheep, .monkey, .rooster, .chicken, .serviceDog, .dog, .pig, .boar, .elephant, .octopus, .spiralShell, .bug, .ant, .honeybee, .ladyBeetle, .fish, .tropicalFish, .blowfish, .turtle, .hatchingChick, .babyChick, .frontfacingBabyChick, .phoenix, .blackBird, .bird, .penguin, .koala, .poodle, .dromedaryCamel, .bactrianCamel, .dolphin, .mouseFace, .cowFace, .tigerFace, .rabbitFace, .catFace, .dragonFace, .spoutingWhale, .horseFace, .monkeyFace, .dogFace, .pigFace, .frogFace, .hamsterFace, .wolfFace, .polarBear, .bearFace, .pandaFace, .pigNose, .pawPrints, .chipmunk, .bouquet, .whiteFlower, .dove, .spider, .spiderWeb, .wiltedFlower, .lionFace, .scorpion, .turkey, .unicornFace, .eagle, .duck, .bat, .shark, .owl, .foxFace, .butterfly, .deer, .gorilla, .lizard, .rhinoceros, .giraffeFace, .zebraFace, .hedgehog, .sauropod, .trex, .cricket, .kangaroo, .llama, .peacock, .hippopotamus, .parrot, .raccoon, .mosquito, .microbe, .badger, .swan, .mammoth, .dodo, .sloth, .otter, .orangutan, .skunk, .flamingo, .beaver, .bison, .seal, .guideDog, .fly, .worm, .beetle, .cockroach, .pottedPlant, .feather, .lotus, .coral, .emptyNest, .nestWithEggs, .hyacinth, .jellyfish, .wing, .goose, .moose, .donkey, .shamrock]
        case .peopleBody:
            return [.fatherChristmas, .snowboarder, .womanRunning, .womanRunningFacingRight, .manRunning, .manRunningFacingRight, .personRunningFacingRight, .runner, .womanSurfing, .manSurfing, .surfer, .horseRacing, .womanSwimming, .manSwimming, .swimmer, .womanLiftingWeights, .manLiftingWeights, .personLiftingWeights, .womanGolfing, .manGolfing, .personGolfing, .eyes, .eye, .ear, .nose, .mouth, .tongue, .whiteUpPointingBackhandIndex, .whiteDownPointingBackhandIndex, .whiteLeftPointingBackhandIndex, .whiteRightPointingBackhandIndex, .fistedHandSign, .wavingHandSign, .okHandSign, .thumbsUpSign, .thumbsDownSign, .clappingHandsSign, .openHandsSign, .footprints, .bustInSilhouette, .bustsInSilhouette, .boy, .girl, .manFarmer, .manCook, .manFeedingBaby, .manStudent, .manSinger, .manArtist, .manTeacher, .manFactoryWorker, .familyManBoyBoy, .familyManBoy, .familyManGirlBoy, .familyManGirlGirl, .familyManGirl, .familyManManBoy, .familyManManBoyBoy, .familyManManGirl, .familyManManGirlBoy, .familyManManGirlGirl, .familyManWomanBoy, .familyManWomanBoyBoy, .familyManWomanGirl, .familyManWomanGirlBoy, .familyManWomanGirlGirl, .manTechnologist, .manOfficeWorker, .manMechanic, .manScientist, .manAstronaut, .manFirefighter, .manWithWhiteCaneFacingRight, .manWithWhiteCane, .manRedHair, .manCurlyHair, .manBald, .manWhiteHair, .manInMotorizedWheelchairFacingRight, .manInMotorizedWheelchair, .manInManualWheelchairFacingRight, .manInManualWheelchair, .manHealthWorker, .manJudge, .manPilot, .coupleWithHeartManMan, .kissManMan, .man, .womanFarmer, .womanCook, .womanFeedingBaby, .womanStudent, .womanSinger, .womanArtist, .womanTeacher, .womanFactoryWorker, .familyWomanBoyBoy, .familyWomanBoy, .familyWomanGirlBoy, .familyWomanGirlGirl, .familyWomanGirl, .familyWomanWomanBoy, .familyWomanWomanBoyBoy, .familyWomanWomanGirl, .familyWomanWomanGirlBoy, .familyWomanWomanGirlGirl, .womanTechnologist, .womanOfficeWorker, .womanMechanic, .womanScientist, .womanAstronaut, .womanFirefighter, .womanWithWhiteCaneFacingRight, .womanWithWhiteCane, .womanRedHair, .womanCurlyHair, .womanBald, .womanWhiteHair, .womanInMotorizedWheelchairFacingRight, .womanInMotorizedWheelchair, .womanInManualWheelchairFacingRight, .womanInManualWheelchair, .womanHealthWorker, .womanJudge, .womanPilot, .coupleWithHeartWomanMan, .coupleWithHeartWomanWoman, .kissWomanMan, .kissWomanWoman, .woman, .family, .manAndWomanHoldingHands, .twoMenHoldingHands, .twoWomenHoldingHands, .womanPoliceOfficer, .manPoliceOfficer, .policeOfficer, .womenWithBunnyEars, .menWithBunnyEars, .womanWithBunnyEars, .womanWithVeil, .manWithVeil, .brideWithVeil, .womanBlondHair, .manBlondHair, .personWithBlondHair, .manWithGuaPiMao, .womanWearingTurban, .manWearingTurban, .manWithTurban, .olderMan, .olderWoman, .baby, .womanConstructionWorker, .manConstructionWorker, .constructionWorker, .princess, .babyAngel, .womanTippingHand, .manTippingHand, .informationDeskPerson, .womanGuard, .manGuard, .guardsman, .dancer, .nailPolish, .womanGettingMassage, .manGettingMassage, .faceMassage, .womanGettingHaircut, .manGettingHaircut, .haircut, .kiss, .coupleWithHeart, .flexedBiceps, .personInSuitLevitating, .womanDetective, .manDetective, .detective, .manDancing, .handWithFingersSplayed, .reversedHandWithMiddleFingerExtended, .raisedHandWithPartBetweenMiddleAndRingFingers, .speakingHead, .womanGesturingNo, .manGesturingNo, .faceWithNoGoodGesture, .womanGesturingOk, .manGesturingOk, .faceWithOkGesture, .womanBowing, .manBowing, .personBowingDeeply, .womanRaisingHand, .manRaisingHand, .happyPersonRaisingOneHand, .personRaisingBothHandsInCelebration, .womanFrowning, .manFrowning, .personFrowning, .womanPouting, .manPouting, .personWithPoutingFace, .personWithFoldedHands, .womanRowingBoat, .manRowingBoat, .rowboat, .womanBiking, .manBiking, .bicyclist, .womanMountainBiking, .manMountainBiking, .mountainBicyclist, .womanWalking, .womanWalkingFacingRight, .manWalking, .manWalkingFacingRight, .personWalkingFacingRight, .pedestrian, .bath, .sleepingAccommodation, .pinchedFingers, .pinchingHand, .signOfTheHorns, .callMeHand, .raisedBackOfHand, .leftfacingFist, .rightfacingFist, .handshake, .handWithIndexAndMiddleFingersCrossed, .iLoveYouHandSign, .womanFacepalming, .manFacepalming, .facePalm, .pregnantWoman, .breastfeeding, .palmsUpTogether, .selfie, .prince, .womanInTuxedo, .manInTuxedo, .motherChristmas, .womanShrugging, .manShrugging, .shrug, .womanCartwheeling, .manCartwheeling, .personDoingCartwheel, .womanJuggling, .manJuggling, .juggling, .fencer, .womenWrestling, .menWrestling, .wrestlers, .womanPlayingWaterPolo, .manPlayingWaterPolo, .waterPolo, .womanPlayingHandball, .manPlayingHandball, .handball, .ninja, .bone, .leg, .foot, .tooth, .womanSuperhero, .manSuperhero, .superhero, .womanSupervillain, .manSupervillain, .supervillain, .earWithHearingAid, .mechanicalArm, .mechanicalLeg, .troll, .womanStanding, .manStanding, .standingPerson, .womanKneeling, .womanKneelingFacingRight, .manKneeling, .manKneelingFacingRight, .personKneelingFacingRight, .kneelingPerson, .deafWoman, .deafMan, .deafPerson, .farmer, .cook, .personFeedingBaby, .mxClaus, .student, .singer, .artist, .teacher, .factoryWorker, .technologist, .officeWorker, .mechanic, .scientist, .astronaut, .firefighter, .peopleHoldingHands, .personWithWhiteCaneFacingRight, .personWithWhiteCane, .personRedHair, .personCurlyHair, .personBald, .personWhiteHair, .personInMotorizedWheelchairFacingRight, .personInMotorizedWheelchair, .personInManualWheelchairFacingRight, .personInManualWheelchair, .familyAdultAdultChild, .familyAdultAdultChildChild, .familyAdultChildChild, .familyAdultChild, .healthWorker, .judge, .pilot, .adult, .child, .olderAdult, .womanBeard, .manBeard, .beardedPerson, .personWithHeadscarf, .womanInSteamyRoom, .manInSteamyRoom, .personInSteamyRoom, .womanClimbing, .manClimbing, .personClimbing, .womanInLotusPosition, .manInLotusPosition, .personInLotusPosition, .womanMage, .manMage, .mage, .womanFairy, .manFairy, .fairy, .womanVampire, .manVampire, .vampire, .mermaid, .merman, .merperson, .womanElf, .manElf, .elf, .womanGenie, .manGenie, .genie, .womanZombie, .manZombie, .zombie, .brain, .anatomicalHeart, .lungs, .peopleHugging, .pregnantMan, .pregnantPerson, .personWithCrown, .bitingLip, .handWithIndexFingerAndThumbCrossed, .rightwardsHand, .leftwardsHand, .palmDownHand, .palmUpHand, .indexPointingAtTheViewer, .heartHands, .leftwardsPushingHand, .rightwardsPushingHand, .whiteUpPointingIndex, .skier, .womanBouncingBall, .manBouncingBall, .personBouncingBall, .raisedFist, .raisedHand, .victoryHand, .writingHand]
        case .objects:
            return [.schoolSatchel, .graduationCap, .studioMicrophone, .levelSlider, .controlKnobs, .filmFrames, .microphone, .movieCamera, .headphone, .topHat, .clapperBoard, .musicalNote, .multipleMusicalNotes, .saxophone, .guitar, .musicalKeyboard, .trumpet, .violin, .musicalScore, .izakayaLantern, .label, .bowAndArrow, .crown, .womansHat, .eyeglasses, .necktie, .tshirt, .jeans, .dress, .kimono, .bikini, .womansClothes, .purse, .handbag, .pouch, .mansShoe, .athleticShoe, .highheeledShoe, .womansSandal, .womansBoots, .lipstick, .syringe, .pill, .ring, .gemStone, .electricLightBulb, .bomb, .moneyBag, .creditCard, .banknoteWithYenSign, .banknoteWithDollarSign, .banknoteWithEuroSign, .banknoteWithPoundSign, .moneyWithWings, .chartWithUpwardsTrendAndYenSign, .personalComputer, .briefcase, .minidisc, .floppyDisk, .opticalDisc, .dvd, .fileFolder, .openFileFolder, .pageWithCurl, .pageFacingUp, .calendar, .tearoffCalendar, .cardIndex, .chartWithUpwardsTrend, .chartWithDownwardsTrend, .barChart, .clipboard, .pushpin, .roundPushpin, .paperclip, .straightRuler, .triangularRuler, .bookmarkTabs, .ledger, .notebook, .notebookWithDecorativeCover, .closedBook, .openBook, .greenBook, .blueBook, .orangeBook, .books, .scroll, .memo, .telephoneReceiver, .pager, .faxMachine, .satelliteAntenna, .publicAddressLoudspeaker, .cheeringMegaphone, .outboxTray, .inboxTray, .package, .emailSymbol, .incomingEnvelope, .envelopeWithDownwardsArrowAbove, .closedMailboxWithLoweredFlag, .closedMailboxWithRaisedFlag, .openMailboxWithRaisedFlag, .openMailboxWithLoweredFlag, .postbox, .postalHorn, .newspaper, .mobilePhone, .mobilePhoneWithRightwardsArrowAtLeft, .camera, .cameraWithFlash, .videoCamera, .television, .radio, .videocassette, .filmProjector, .prayerBeads, .speakerWithCancellationStroke, .speaker, .speakerWithOneSoundWave, .speakerWithThreeSoundWaves, .battery, .electricPlug, .leftpointingMagnifyingGlass, .rightpointingMagnifyingGlass, .lockWithInkPen, .closedLockWithKey, .key, .lock, .openLock, .bell, .bellWithCancellationStroke, .bookmark, .linkSymbol, .electricTorch, .wrench, .hammer, .nutAndBolt, .microscope, .telescope, .candle, .sunglasses, .linkedPaperclips, .pen, .fountainPen, .paintbrush, .crayon, .desktopComputer, .printer, .computerMouse, .trackball, .cardIndexDividers, .cardFileBox, .fileCabinet, .wastebasket, .spiralNotepad, .spiralCalendar, .clamp, .oldKey, .rolledupNewspaper, .dagger, .ballotBoxWithBallot, .moyai, .door, .smokingSymbol, .toilet, .shower, .bathtub, .couchAndLamp, .shoppingBags, .bed, .shoppingTrolley, .elevator, .hammerAndWrench, .shield, .drumWithDrumsticks, .sari, .labCoat, .goggles, .hikingBoot, .flatShoe, .probingCane, .safetyVest, .billedCap, .scarf, .gloves, .coat, .socks, .testTube, .petriDish, .dnaDoubleHelix, .abacus, .fireExtinguisher, .toolbox, .magnet, .lotionBottle, .safetyPin, .broom, .basket, .rollOfPaper, .barOfSoap, .sponge, .receipt, .nazarAmulet, .balletShoes, .onepieceSwimsuit, .briefs, .shorts, .thongSandal, .dropOfBlood, .adhesiveBandage, .stethoscope, .xray, .crutch, .boomerang, .maracas, .flute, .chair, .razor, .axe, .diyaLamp, .banjo, .militaryHelmet, .accordion, .longDrum, .coin, .carpentrySaw, .screwdriver, .ladder, .hook, .mirror, .window, .plunger, .bucket, .mouseTrap, .toothbrush, .headstone, .placard, .identificationCard, .lowBattery, .hamsa, .foldingHandFan, .hairPick, .bubbles, .keyboard, .blackTelephone, .hammerAndPick, .crossedSwords, .balanceScale, .alembic, .gear, .coffin, .funeralUrn, .pick, .rescueWorkersHelmet, .brokenChain, .chains, .blackScissors, .envelope, .pencil, .blackNib]
        case .component:
            return [.emojiModifierFitzpatrickType12, .emojiModifierFitzpatrickType3, .emojiModifierFitzpatrickType4, .emojiModifierFitzpatrickType5, .emojiModifierFitzpatrickType6]
        case .smileysEmotion:
            return [.eyeInSpeechBubble, .japaneseOgre, .japaneseGoblin, .ghost, .extraterrestrialAlien, .alienMonster, .imp, .skull, .kissMark, .loveLetter, .beatingHeart, .brokenHeart, .twoHearts, .sparklingHeart, .growingHeart, .heartWithArrow, .blueHeart, .greenHeart, .yellowHeart, .purpleHeart, .heartWithRibbon, .revolvingHearts, .heartDecoration, .angerSymbol, .sleepingSymbol, .collisionSymbol, .splashingSweatSymbol, .dashSymbol, .pileOfPoo, .dizzySymbol, .speechBalloon, .thoughtBalloon, .hundredPointsSymbol, .hole, .blackHeart, .leftSpeechBubble, .rightAngerBubble, .grinningFace, .grinningFaceWithSmilingEyes, .faceWithTearsOfJoy, .smilingFaceWithOpenMouth, .smilingFaceWithOpenMouthAndSmilingEyes, .smilingFaceWithOpenMouthAndColdSweat, .smilingFaceWithOpenMouthAndTightlyclosedEyes, .smilingFaceWithHalo, .smilingFaceWithHorns, .winkingFace, .smilingFaceWithSmilingEyes, .faceSavouringDeliciousFood, .relievedFace, .smilingFaceWithHeartshapedEyes, .smilingFaceWithSunglasses, .smirkingFace, .neutralFace, .expressionlessFace, .unamusedFace, .faceWithColdSweat, .pensiveFace, .confusedFace, .confoundedFace, .kissingFace, .faceThrowingAKiss, .kissingFaceWithSmilingEyes, .kissingFaceWithClosedEyes, .faceWithStuckoutTongue, .faceWithStuckoutTongueAndWinkingEye, .faceWithStuckoutTongueAndTightlyclosedEyes, .disappointedFace, .worriedFace, .angryFace, .poutingFace, .cryingFace, .perseveringFace, .faceWithLookOfTriumph, .disappointedButRelievedFace, .frowningFaceWithOpenMouth, .anguishedFace, .fearfulFace, .wearyFace, .sleepyFace, .tiredFace, .grimacingFace, .loudlyCryingFace, .faceExhaling, .faceWithOpenMouth, .hushedFace, .faceWithOpenMouthAndColdSweat, .faceScreamingInFear, .astonishedFace, .flushedFace, .sleepingFace, .faceWithSpiralEyes, .dizzyFace, .faceInClouds, .faceWithoutMouth, .faceWithMedicalMask, .grinningCatFaceWithSmilingEyes, .catFaceWithTearsOfJoy, .smilingCatFaceWithOpenMouth, .smilingCatFaceWithHeartshapedEyes, .catFaceWithWrySmile, .kissingCatFaceWithClosedEyes, .poutingCatFace, .cryingCatFace, .wearyCatFace, .slightlyFrowningFace, .headShakingHorizontally, .headShakingVertically, .slightlySmilingFace, .upsidedownFace, .faceWithRollingEyes, .seenoevilMonkey, .hearnoevilMonkey, .speaknoevilMonkey, .whiteHeart, .brownHeart, .zippermouthFace, .moneymouthFace, .faceWithThermometer, .nerdFace, .thinkingFace, .faceWithHeadbandage, .robotFace, .huggingFace, .faceWithCowboyHat, .clownFace, .nauseatedFace, .rollingOnTheFloorLaughing, .droolingFace, .lyingFace, .sneezingFace, .faceWithOneEyebrowRaised, .grinningFaceWithStarEyes, .grinningFaceWithOneLargeAndOneSmallEye, .faceWithFingerCoveringClosedLips, .seriousFaceWithSymbolsCoveringMouth, .smilingFaceWithSmilingEyesAndHandCoveringMouth, .faceWithOpenMouthVomiting, .shockedFaceWithExplodingHead, .smilingFaceWithSmilingEyesAndThreeHearts, .yawningFace, .smilingFaceWithTear, .faceWithPartyHornAndPartyHat, .faceWithUnevenEyesAndWavyMouth, .overheatedFace, .freezingFace, .disguisedFace, .faceHoldingBackTears, .faceWithPleadingEyes, .faceWithMonocle, .orangeHeart, .lightBlueHeart, .greyHeart, .pinkHeart, .meltingFace, .salutingFace, .faceWithOpenEyesAndHandOverMouth, .faceWithPeekingEye, .faceWithDiagonalMouth, .dottedLineFace, .shakingFace, .skullAndCrossbones, .frowningFace, .whiteSmilingFace, .heartExclamation, .heartOnFire, .mendingHeart, .heavyBlackHeart]
        }
    }
}

extension Emoji {
    var name: String {
        switch self {
        case .hashKey: return "HASH KEY"
        case .keycap: return "KEYCAP: *"
        case .keycap0: return "KEYCAP 0"
        case .keycap1: return "KEYCAP 1"
        case .keycap2: return "KEYCAP 2"
        case .keycap3: return "KEYCAP 3"
        case .keycap4: return "KEYCAP 4"
        case .keycap5: return "KEYCAP 5"
        case .keycap6: return "KEYCAP 6"
        case .keycap7: return "KEYCAP 7"
        case .keycap8: return "KEYCAP 8"
        case .keycap9: return "KEYCAP 9"
        case .copyrightSign: return "COPYRIGHT SIGN"
        case .registeredSign: return "REGISTERED SIGN"
        case .mahjongTileRedDragon: return "MAHJONG TILE RED DRAGON"
        case .playingCardBlackJoker: return "PLAYING CARD BLACK JOKER"
        case .negativeSquaredLatinCapitalLetterA: return "NEGATIVE SQUARED LATIN CAPITAL LETTER A"
        case .negativeSquaredLatinCapitalLetterB: return "NEGATIVE SQUARED LATIN CAPITAL LETTER B"
        case .negativeSquaredLatinCapitalLetterO: return "NEGATIVE SQUARED LATIN CAPITAL LETTER O"
        case .negativeSquaredLatinCapitalLetterP: return "NEGATIVE SQUARED LATIN CAPITAL LETTER P"
        case .negativeSquaredAb: return "NEGATIVE SQUARED AB"
        case .squaredCl: return "SQUARED CL"
        case .squaredCool: return "SQUARED COOL"
        case .squaredFree: return "SQUARED FREE"
        case .squaredId: return "SQUARED ID"
        case .squaredNew: return "SQUARED NEW"
        case .squaredNg: return "SQUARED NG"
        case .squaredOk: return "SQUARED OK"
        case .squaredSos: return "SQUARED SOS"
        case .squaredUpWithExclamationMark: return "SQUARED UP WITH EXCLAMATION MARK"
        case .squaredVs: return "SQUARED VS"
        case .ascensionIslandFlag: return "Ascension Island Flag"
        case .andorraFlag: return "Andorra Flag"
        case .unitedArabEmiratesFlag: return "United Arab Emirates Flag"
        case .afghanistanFlag: return "Afghanistan Flag"
        case .antiguaBarbudaFlag: return "Antigua & Barbuda Flag"
        case .anguillaFlag: return "Anguilla Flag"
        case .albaniaFlag: return "Albania Flag"
        case .armeniaFlag: return "Armenia Flag"
        case .angolaFlag: return "Angola Flag"
        case .antarcticaFlag: return "Antarctica Flag"
        case .argentinaFlag: return "Argentina Flag"
        case .americanSamoaFlag: return "American Samoa Flag"
        case .austriaFlag: return "Austria Flag"
        case .australiaFlag: return "Australia Flag"
        case .arubaFlag: return "Aruba Flag"
        case .ålandIslandsFlag: return "Åland Islands Flag"
        case .azerbaijanFlag: return "Azerbaijan Flag"
        case .bosniaHerzegovinaFlag: return "Bosnia & Herzegovina Flag"
        case .barbadosFlag: return "Barbados Flag"
        case .bangladeshFlag: return "Bangladesh Flag"
        case .belgiumFlag: return "Belgium Flag"
        case .burkinaFasoFlag: return "Burkina Faso Flag"
        case .bulgariaFlag: return "Bulgaria Flag"
        case .bahrainFlag: return "Bahrain Flag"
        case .burundiFlag: return "Burundi Flag"
        case .beninFlag: return "Benin Flag"
        case .stBarthélemyFlag: return "St. Barthélemy Flag"
        case .bermudaFlag: return "Bermuda Flag"
        case .bruneiFlag: return "Brunei Flag"
        case .boliviaFlag: return "Bolivia Flag"
        case .caribbeanNetherlandsFlag: return "Caribbean Netherlands Flag"
        case .brazilFlag: return "Brazil Flag"
        case .bahamasFlag: return "Bahamas Flag"
        case .bhutanFlag: return "Bhutan Flag"
        case .bouvetIslandFlag: return "Bouvet Island Flag"
        case .botswanaFlag: return "Botswana Flag"
        case .belarusFlag: return "Belarus Flag"
        case .belizeFlag: return "Belize Flag"
        case .canadaFlag: return "Canada Flag"
        case .cocosKeelingIslandsFlag: return "Cocos (Keeling) Islands Flag"
        case .congoKinshasaFlag: return "Congo - Kinshasa Flag"
        case .centralAfricanRepublicFlag: return "Central African Republic Flag"
        case .congoBrazzavilleFlag: return "Congo - Brazzaville Flag"
        case .switzerlandFlag: return "Switzerland Flag"
        case .côteDivoireFlag: return "Côte d’Ivoire Flag"
        case .cookIslandsFlag: return "Cook Islands Flag"
        case .chileFlag: return "Chile Flag"
        case .cameroonFlag: return "Cameroon Flag"
        case .chinaFlag: return "China Flag"
        case .colombiaFlag: return "Colombia Flag"
        case .clippertonIslandFlag: return "Clipperton Island Flag"
        case .costaRicaFlag: return "Costa Rica Flag"
        case .cubaFlag: return "Cuba Flag"
        case .capeVerdeFlag: return "Cape Verde Flag"
        case .curaçaoFlag: return "Curaçao Flag"
        case .christmasIslandFlag: return "Christmas Island Flag"
        case .cyprusFlag: return "Cyprus Flag"
        case .czechiaFlag: return "Czechia Flag"
        case .germanyFlag: return "Germany Flag"
        case .diegoGarciaFlag: return "Diego Garcia Flag"
        case .djiboutiFlag: return "Djibouti Flag"
        case .denmarkFlag: return "Denmark Flag"
        case .dominicaFlag: return "Dominica Flag"
        case .dominicanRepublicFlag: return "Dominican Republic Flag"
        case .algeriaFlag: return "Algeria Flag"
        case .ceutaMelillaFlag: return "Ceuta & Melilla Flag"
        case .ecuadorFlag: return "Ecuador Flag"
        case .estoniaFlag: return "Estonia Flag"
        case .egyptFlag: return "Egypt Flag"
        case .westernSaharaFlag: return "Western Sahara Flag"
        case .eritreaFlag: return "Eritrea Flag"
        case .spainFlag: return "Spain Flag"
        case .ethiopiaFlag: return "Ethiopia Flag"
        case .europeanUnionFlag: return "European Union Flag"
        case .finlandFlag: return "Finland Flag"
        case .fijiFlag: return "Fiji Flag"
        case .falklandIslandsFlag: return "Falkland Islands Flag"
        case .micronesiaFlag: return "Micronesia Flag"
        case .faroeIslandsFlag: return "Faroe Islands Flag"
        case .franceFlag: return "France Flag"
        case .gabonFlag: return "Gabon Flag"
        case .unitedKingdomFlag: return "United Kingdom Flag"
        case .grenadaFlag: return "Grenada Flag"
        case .georgiaFlag: return "Georgia Flag"
        case .frenchGuianaFlag: return "French Guiana Flag"
        case .guernseyFlag: return "Guernsey Flag"
        case .ghanaFlag: return "Ghana Flag"
        case .gibraltarFlag: return "Gibraltar Flag"
        case .greenlandFlag: return "Greenland Flag"
        case .gambiaFlag: return "Gambia Flag"
        case .guineaFlag: return "Guinea Flag"
        case .guadeloupeFlag: return "Guadeloupe Flag"
        case .equatorialGuineaFlag: return "Equatorial Guinea Flag"
        case .greeceFlag: return "Greece Flag"
        case .southGeorgiaSouthSandwichIslandsFlag: return "South Georgia & South Sandwich Islands Flag"
        case .guatemalaFlag: return "Guatemala Flag"
        case .guamFlag: return "Guam Flag"
        case .guineabissauFlag: return "Guinea-Bissau Flag"
        case .guyanaFlag: return "Guyana Flag"
        case .hongKongSarChinaFlag: return "Hong Kong SAR China Flag"
        case .heardMcdonaldIslandsFlag: return "Heard & McDonald Islands Flag"
        case .hondurasFlag: return "Honduras Flag"
        case .croatiaFlag: return "Croatia Flag"
        case .haitiFlag: return "Haiti Flag"
        case .hungaryFlag: return "Hungary Flag"
        case .canaryIslandsFlag: return "Canary Islands Flag"
        case .indonesiaFlag: return "Indonesia Flag"
        case .irelandFlag: return "Ireland Flag"
        case .israelFlag: return "Israel Flag"
        case .isleOfManFlag: return "Isle of Man Flag"
        case .indiaFlag: return "India Flag"
        case .britishIndianOceanTerritoryFlag: return "British Indian Ocean Territory Flag"
        case .iraqFlag: return "Iraq Flag"
        case .iranFlag: return "Iran Flag"
        case .icelandFlag: return "Iceland Flag"
        case .italyFlag: return "Italy Flag"
        case .jerseyFlag: return "Jersey Flag"
        case .jamaicaFlag: return "Jamaica Flag"
        case .jordanFlag: return "Jordan Flag"
        case .japanFlag: return "Japan Flag"
        case .kenyaFlag: return "Kenya Flag"
        case .kyrgyzstanFlag: return "Kyrgyzstan Flag"
        case .cambodiaFlag: return "Cambodia Flag"
        case .kiribatiFlag: return "Kiribati Flag"
        case .comorosFlag: return "Comoros Flag"
        case .stKittsNevisFlag: return "St. Kitts & Nevis Flag"
        case .northKoreaFlag: return "North Korea Flag"
        case .southKoreaFlag: return "South Korea Flag"
        case .kuwaitFlag: return "Kuwait Flag"
        case .caymanIslandsFlag: return "Cayman Islands Flag"
        case .kazakhstanFlag: return "Kazakhstan Flag"
        case .laosFlag: return "Laos Flag"
        case .lebanonFlag: return "Lebanon Flag"
        case .stLuciaFlag: return "St. Lucia Flag"
        case .liechtensteinFlag: return "Liechtenstein Flag"
        case .sriLankaFlag: return "Sri Lanka Flag"
        case .liberiaFlag: return "Liberia Flag"
        case .lesothoFlag: return "Lesotho Flag"
        case .lithuaniaFlag: return "Lithuania Flag"
        case .luxembourgFlag: return "Luxembourg Flag"
        case .latviaFlag: return "Latvia Flag"
        case .libyaFlag: return "Libya Flag"
        case .moroccoFlag: return "Morocco Flag"
        case .monacoFlag: return "Monaco Flag"
        case .moldovaFlag: return "Moldova Flag"
        case .montenegroFlag: return "Montenegro Flag"
        case .stMartinFlag: return "St. Martin Flag"
        case .madagascarFlag: return "Madagascar Flag"
        case .marshallIslandsFlag: return "Marshall Islands Flag"
        case .northMacedoniaFlag: return "North Macedonia Flag"
        case .maliFlag: return "Mali Flag"
        case .myanmarBurmaFlag: return "Myanmar (Burma) Flag"
        case .mongoliaFlag: return "Mongolia Flag"
        case .macaoSarChinaFlag: return "Macao SAR China Flag"
        case .northernMarianaIslandsFlag: return "Northern Mariana Islands Flag"
        case .martiniqueFlag: return "Martinique Flag"
        case .mauritaniaFlag: return "Mauritania Flag"
        case .montserratFlag: return "Montserrat Flag"
        case .maltaFlag: return "Malta Flag"
        case .mauritiusFlag: return "Mauritius Flag"
        case .maldivesFlag: return "Maldives Flag"
        case .malawiFlag: return "Malawi Flag"
        case .mexicoFlag: return "Mexico Flag"
        case .malaysiaFlag: return "Malaysia Flag"
        case .mozambiqueFlag: return "Mozambique Flag"
        case .namibiaFlag: return "Namibia Flag"
        case .newCaledoniaFlag: return "New Caledonia Flag"
        case .nigerFlag: return "Niger Flag"
        case .norfolkIslandFlag: return "Norfolk Island Flag"
        case .nigeriaFlag: return "Nigeria Flag"
        case .nicaraguaFlag: return "Nicaragua Flag"
        case .netherlandsFlag: return "Netherlands Flag"
        case .norwayFlag: return "Norway Flag"
        case .nepalFlag: return "Nepal Flag"
        case .nauruFlag: return "Nauru Flag"
        case .niueFlag: return "Niue Flag"
        case .newZealandFlag: return "New Zealand Flag"
        case .omanFlag: return "Oman Flag"
        case .panamaFlag: return "Panama Flag"
        case .peruFlag: return "Peru Flag"
        case .frenchPolynesiaFlag: return "French Polynesia Flag"
        case .papuaNewGuineaFlag: return "Papua New Guinea Flag"
        case .philippinesFlag: return "Philippines Flag"
        case .pakistanFlag: return "Pakistan Flag"
        case .polandFlag: return "Poland Flag"
        case .stPierreMiquelonFlag: return "St. Pierre & Miquelon Flag"
        case .pitcairnIslandsFlag: return "Pitcairn Islands Flag"
        case .puertoRicoFlag: return "Puerto Rico Flag"
        case .palestinianTerritoriesFlag: return "Palestinian Territories Flag"
        case .portugalFlag: return "Portugal Flag"
        case .palauFlag: return "Palau Flag"
        case .paraguayFlag: return "Paraguay Flag"
        case .qatarFlag: return "Qatar Flag"
        case .réunionFlag: return "Réunion Flag"
        case .romaniaFlag: return "Romania Flag"
        case .serbiaFlag: return "Serbia Flag"
        case .russiaFlag: return "Russia Flag"
        case .rwandaFlag: return "Rwanda Flag"
        case .saudiArabiaFlag: return "Saudi Arabia Flag"
        case .solomonIslandsFlag: return "Solomon Islands Flag"
        case .seychellesFlag: return "Seychelles Flag"
        case .sudanFlag: return "Sudan Flag"
        case .swedenFlag: return "Sweden Flag"
        case .singaporeFlag: return "Singapore Flag"
        case .stHelenaFlag: return "St. Helena Flag"
        case .sloveniaFlag: return "Slovenia Flag"
        case .svalbardJanMayenFlag: return "Svalbard & Jan Mayen Flag"
        case .slovakiaFlag: return "Slovakia Flag"
        case .sierraLeoneFlag: return "Sierra Leone Flag"
        case .sanMarinoFlag: return "San Marino Flag"
        case .senegalFlag: return "Senegal Flag"
        case .somaliaFlag: return "Somalia Flag"
        case .surinameFlag: return "Suriname Flag"
        case .southSudanFlag: return "South Sudan Flag"
        case .sãoToméPríncipeFlag: return "São Tomé & Príncipe Flag"
        case .elSalvadorFlag: return "El Salvador Flag"
        case .sintMaartenFlag: return "Sint Maarten Flag"
        case .syriaFlag: return "Syria Flag"
        case .eswatiniFlag: return "Eswatini Flag"
        case .tristanDaCunhaFlag: return "Tristan da Cunha Flag"
        case .turksCaicosIslandsFlag: return "Turks & Caicos Islands Flag"
        case .chadFlag: return "Chad Flag"
        case .frenchSouthernTerritoriesFlag: return "French Southern Territories Flag"
        case .togoFlag: return "Togo Flag"
        case .thailandFlag: return "Thailand Flag"
        case .tajikistanFlag: return "Tajikistan Flag"
        case .tokelauFlag: return "Tokelau Flag"
        case .timorlesteFlag: return "Timor-Leste Flag"
        case .turkmenistanFlag: return "Turkmenistan Flag"
        case .tunisiaFlag: return "Tunisia Flag"
        case .tongaFlag: return "Tonga Flag"
        case .türkiyeFlag: return "Türkiye Flag"
        case .trinidadTobagoFlag: return "Trinidad & Tobago Flag"
        case .tuvaluFlag: return "Tuvalu Flag"
        case .taiwanFlag: return "Taiwan Flag"
        case .tanzaniaFlag: return "Tanzania Flag"
        case .ukraineFlag: return "Ukraine Flag"
        case .ugandaFlag: return "Uganda Flag"
        case .usOutlyingIslandsFlag: return "U.S. Outlying Islands Flag"
        case .unitedNationsFlag: return "United Nations Flag"
        case .unitedStatesFlag: return "United States Flag"
        case .uruguayFlag: return "Uruguay Flag"
        case .uzbekistanFlag: return "Uzbekistan Flag"
        case .vaticanCityFlag: return "Vatican City Flag"
        case .stVincentGrenadinesFlag: return "St. Vincent & Grenadines Flag"
        case .venezuelaFlag: return "Venezuela Flag"
        case .britishVirginIslandsFlag: return "British Virgin Islands Flag"
        case .usVirginIslandsFlag: return "U.S. Virgin Islands Flag"
        case .vietnamFlag: return "Vietnam Flag"
        case .vanuatuFlag: return "Vanuatu Flag"
        case .wallisFutunaFlag: return "Wallis & Futuna Flag"
        case .samoaFlag: return "Samoa Flag"
        case .kosovoFlag: return "Kosovo Flag"
        case .yemenFlag: return "Yemen Flag"
        case .mayotteFlag: return "Mayotte Flag"
        case .southAfricaFlag: return "South Africa Flag"
        case .zambiaFlag: return "Zambia Flag"
        case .zimbabweFlag: return "Zimbabwe Flag"
        case .squaredKatakanaKoko: return "SQUARED KATAKANA KOKO"
        case .squaredKatakanaSa: return "SQUARED KATAKANA SA"
        case .squaredCjkUnifiedIdeograph7121: return "SQUARED CJK UNIFIED IDEOGRAPH-7121"
        case .squaredCjkUnifiedIdeograph6307: return "SQUARED CJK UNIFIED IDEOGRAPH-6307"
        case .squaredCjkUnifiedIdeograph7981: return "SQUARED CJK UNIFIED IDEOGRAPH-7981"
        case .squaredCjkUnifiedIdeograph7A7A: return "SQUARED CJK UNIFIED IDEOGRAPH-7A7A"
        case .squaredCjkUnifiedIdeograph5408: return "SQUARED CJK UNIFIED IDEOGRAPH-5408"
        case .squaredCjkUnifiedIdeograph6E80: return "SQUARED CJK UNIFIED IDEOGRAPH-6E80"
        case .squaredCjkUnifiedIdeograph6709: return "SQUARED CJK UNIFIED IDEOGRAPH-6709"
        case .squaredCjkUnifiedIdeograph6708: return "SQUARED CJK UNIFIED IDEOGRAPH-6708"
        case .squaredCjkUnifiedIdeograph7533: return "SQUARED CJK UNIFIED IDEOGRAPH-7533"
        case .squaredCjkUnifiedIdeograph5272: return "SQUARED CJK UNIFIED IDEOGRAPH-5272"
        case .squaredCjkUnifiedIdeograph55B6: return "SQUARED CJK UNIFIED IDEOGRAPH-55B6"
        case .circledIdeographAdvantage: return "CIRCLED IDEOGRAPH ADVANTAGE"
        case .circledIdeographAccept: return "CIRCLED IDEOGRAPH ACCEPT"
        case .cyclone: return "CYCLONE"
        case .foggy: return "FOGGY"
        case .closedUmbrella: return "CLOSED UMBRELLA"
        case .nightWithStars: return "NIGHT WITH STARS"
        case .sunriseOverMountains: return "SUNRISE OVER MOUNTAINS"
        case .sunrise: return "SUNRISE"
        case .cityscapeAtDusk: return "CITYSCAPE AT DUSK"
        case .sunsetOverBuildings: return "SUNSET OVER BUILDINGS"
        case .rainbow: return "RAINBOW"
        case .bridgeAtNight: return "BRIDGE AT NIGHT"
        case .waterWave: return "WATER WAVE"
        case .volcano: return "VOLCANO"
        case .milkyWay: return "MILKY WAY"
        case .earthGlobeEuropeafrica: return "EARTH GLOBE EUROPE-AFRICA"
        case .earthGlobeAmericas: return "EARTH GLOBE AMERICAS"
        case .earthGlobeAsiaaustralia: return "EARTH GLOBE ASIA-AUSTRALIA"
        case .globeWithMeridians: return "GLOBE WITH MERIDIANS"
        case .newMoonSymbol: return "NEW MOON SYMBOL"
        case .waxingCrescentMoonSymbol: return "WAXING CRESCENT MOON SYMBOL"
        case .firstQuarterMoonSymbol: return "FIRST QUARTER MOON SYMBOL"
        case .waxingGibbousMoonSymbol: return "WAXING GIBBOUS MOON SYMBOL"
        case .fullMoonSymbol: return "FULL MOON SYMBOL"
        case .waningGibbousMoonSymbol: return "WANING GIBBOUS MOON SYMBOL"
        case .lastQuarterMoonSymbol: return "LAST QUARTER MOON SYMBOL"
        case .waningCrescentMoonSymbol: return "WANING CRESCENT MOON SYMBOL"
        case .crescentMoon: return "CRESCENT MOON"
        case .newMoonWithFace: return "NEW MOON WITH FACE"
        case .firstQuarterMoonWithFace: return "FIRST QUARTER MOON WITH FACE"
        case .lastQuarterMoonWithFace: return "LAST QUARTER MOON WITH FACE"
        case .fullMoonWithFace: return "FULL MOON WITH FACE"
        case .sunWithFace: return "SUN WITH FACE"
        case .glowingStar: return "GLOWING STAR"
        case .shootingStar: return "SHOOTING STAR"
        case .thermometer: return "THERMOMETER"
        case .sunBehindSmallCloud: return "SUN BEHIND SMALL CLOUD"
        case .sunBehindLargeCloud: return "SUN BEHIND LARGE CLOUD"
        case .sunBehindRainCloud: return "SUN BEHIND RAIN CLOUD"
        case .cloudWithRain: return "CLOUD WITH RAIN"
        case .cloudWithSnow: return "CLOUD WITH SNOW"
        case .cloudWithLightning: return "CLOUD WITH LIGHTNING"
        case .tornado: return "TORNADO"
        case .fog: return "FOG"
        case .windFace: return "WIND FACE"
        case .hotDog: return "HOT DOG"
        case .taco: return "TACO"
        case .burrito: return "BURRITO"
        case .chestnut: return "CHESTNUT"
        case .seedling: return "SEEDLING"
        case .evergreenTree: return "EVERGREEN TREE"
        case .deciduousTree: return "DECIDUOUS TREE"
        case .palmTree: return "PALM TREE"
        case .cactus: return "CACTUS"
        case .hotPepper: return "HOT PEPPER"
        case .tulip: return "TULIP"
        case .cherryBlossom: return "CHERRY BLOSSOM"
        case .rose: return "ROSE"
        case .hibiscus: return "HIBISCUS"
        case .sunflower: return "SUNFLOWER"
        case .blossom: return "BLOSSOM"
        case .earOfMaize: return "EAR OF MAIZE"
        case .earOfRice: return "EAR OF RICE"
        case .herb: return "HERB"
        case .fourLeafClover: return "FOUR LEAF CLOVER"
        case .mapleLeaf: return "MAPLE LEAF"
        case .fallenLeaf: return "FALLEN LEAF"
        case .leafFlutteringInWind: return "LEAF FLUTTERING IN WIND"
        case .brownMushroom: return "BROWN MUSHROOM"
        case .mushroom: return "MUSHROOM"
        case .tomato: return "TOMATO"
        case .aubergine: return "AUBERGINE"
        case .grapes: return "GRAPES"
        case .melon: return "MELON"
        case .watermelon: return "WATERMELON"
        case .tangerine: return "TANGERINE"
        case .lime: return "LIME"
        case .lemon: return "LEMON"
        case .banana: return "BANANA"
        case .pineapple: return "PINEAPPLE"
        case .redApple: return "RED APPLE"
        case .greenApple: return "GREEN APPLE"
        case .pear: return "PEAR"
        case .peach: return "PEACH"
        case .cherries: return "CHERRIES"
        case .strawberry: return "STRAWBERRY"
        case .hamburger: return "HAMBURGER"
        case .sliceOfPizza: return "SLICE OF PIZZA"
        case .meatOnBone: return "MEAT ON BONE"
        case .poultryLeg: return "POULTRY LEG"
        case .riceCracker: return "RICE CRACKER"
        case .riceBall: return "RICE BALL"
        case .cookedRice: return "COOKED RICE"
        case .curryAndRice: return "CURRY AND RICE"
        case .steamingBowl: return "STEAMING BOWL"
        case .spaghetti: return "SPAGHETTI"
        case .bread: return "BREAD"
        case .frenchFries: return "FRENCH FRIES"
        case .roastedSweetPotato: return "ROASTED SWEET POTATO"
        case .dango: return "DANGO"
        case .oden: return "ODEN"
        case .sushi: return "SUSHI"
        case .friedShrimp: return "FRIED SHRIMP"
        case .fishCakeWithSwirlDesign: return "FISH CAKE WITH SWIRL DESIGN"
        case .softIceCream: return "SOFT ICE CREAM"
        case .shavedIce: return "SHAVED ICE"
        case .iceCream: return "ICE CREAM"
        case .doughnut: return "DOUGHNUT"
        case .cookie: return "COOKIE"
        case .chocolateBar: return "CHOCOLATE BAR"
        case .candy: return "CANDY"
        case .lollipop: return "LOLLIPOP"
        case .custard: return "CUSTARD"
        case .honeyPot: return "HONEY POT"
        case .shortcake: return "SHORTCAKE"
        case .bentoBox: return "BENTO BOX"
        case .potOfFood: return "POT OF FOOD"
        case .cooking: return "COOKING"
        case .forkAndKnife: return "FORK AND KNIFE"
        case .teacupWithoutHandle: return "TEACUP WITHOUT HANDLE"
        case .sakeBottleAndCup: return "SAKE BOTTLE AND CUP"
        case .wineGlass: return "WINE GLASS"
        case .cocktailGlass: return "COCKTAIL GLASS"
        case .tropicalDrink: return "TROPICAL DRINK"
        case .beerMug: return "BEER MUG"
        case .clinkingBeerMugs: return "CLINKING BEER MUGS"
        case .babyBottle: return "BABY BOTTLE"
        case .forkAndKnifeWithPlate: return "FORK AND KNIFE WITH PLATE"
        case .bottleWithPoppingCork: return "BOTTLE WITH POPPING CORK"
        case .popcorn: return "POPCORN"
        case .ribbon: return "RIBBON"
        case .wrappedPresent: return "WRAPPED PRESENT"
        case .birthdayCake: return "BIRTHDAY CAKE"
        case .jackolantern: return "JACK-O-LANTERN"
        case .christmasTree: return "CHRISTMAS TREE"
        case .fatherChristmas: return "FATHER CHRISTMAS"
        case .fireworks: return "FIREWORKS"
        case .fireworkSparkler: return "FIREWORK SPARKLER"
        case .balloon: return "BALLOON"
        case .partyPopper: return "PARTY POPPER"
        case .confettiBall: return "CONFETTI BALL"
        case .tanabataTree: return "TANABATA TREE"
        case .crossedFlags: return "CROSSED FLAGS"
        case .pineDecoration: return "PINE DECORATION"
        case .japaneseDolls: return "JAPANESE DOLLS"
        case .carpStreamer: return "CARP STREAMER"
        case .windChime: return "WIND CHIME"
        case .moonViewingCeremony: return "MOON VIEWING CEREMONY"
        case .schoolSatchel: return "SCHOOL SATCHEL"
        case .graduationCap: return "GRADUATION CAP"
        case .militaryMedal: return "MILITARY MEDAL"
        case .reminderRibbon: return "REMINDER RIBBON"
        case .studioMicrophone: return "STUDIO MICROPHONE"
        case .levelSlider: return "LEVEL SLIDER"
        case .controlKnobs: return "CONTROL KNOBS"
        case .filmFrames: return "FILM FRAMES"
        case .admissionTickets: return "ADMISSION TICKETS"
        case .carouselHorse: return "CAROUSEL HORSE"
        case .ferrisWheel: return "FERRIS WHEEL"
        case .rollerCoaster: return "ROLLER COASTER"
        case .fishingPoleAndFish: return "FISHING POLE AND FISH"
        case .microphone: return "MICROPHONE"
        case .movieCamera: return "MOVIE CAMERA"
        case .cinema: return "CINEMA"
        case .headphone: return "HEADPHONE"
        case .artistPalette: return "ARTIST PALETTE"
        case .topHat: return "TOP HAT"
        case .circusTent: return "CIRCUS TENT"
        case .ticket: return "TICKET"
        case .clapperBoard: return "CLAPPER BOARD"
        case .performingArts: return "PERFORMING ARTS"
        case .videoGame: return "VIDEO GAME"
        case .directHit: return "DIRECT HIT"
        case .slotMachine: return "SLOT MACHINE"
        case .billiards: return "BILLIARDS"
        case .gameDie: return "GAME DIE"
        case .bowling: return "BOWLING"
        case .flowerPlayingCards: return "FLOWER PLAYING CARDS"
        case .musicalNote: return "MUSICAL NOTE"
        case .multipleMusicalNotes: return "MULTIPLE MUSICAL NOTES"
        case .saxophone: return "SAXOPHONE"
        case .guitar: return "GUITAR"
        case .musicalKeyboard: return "MUSICAL KEYBOARD"
        case .trumpet: return "TRUMPET"
        case .violin: return "VIOLIN"
        case .musicalScore: return "MUSICAL SCORE"
        case .runningShirtWithSash: return "RUNNING SHIRT WITH SASH"
        case .tennisRacquetAndBall: return "TENNIS RACQUET AND BALL"
        case .skiAndSkiBoot: return "SKI AND SKI BOOT"
        case .basketballAndHoop: return "BASKETBALL AND HOOP"
        case .chequeredFlag: return "CHEQUERED FLAG"
        case .snowboarder: return "SNOWBOARDER"
        case .womanRunning: return "WOMAN RUNNING"
        case .womanRunningFacingRight: return "WOMAN RUNNING FACING RIGHT"
        case .manRunning: return "MAN RUNNING"
        case .manRunningFacingRight: return "MAN RUNNING FACING RIGHT"
        case .personRunningFacingRight: return "PERSON RUNNING FACING RIGHT"
        case .runner: return "RUNNER"
        case .womanSurfing: return "WOMAN SURFING"
        case .manSurfing: return "MAN SURFING"
        case .surfer: return "SURFER"
        case .sportsMedal: return "SPORTS MEDAL"
        case .trophy: return "TROPHY"
        case .horseRacing: return "HORSE RACING"
        case .americanFootball: return "AMERICAN FOOTBALL"
        case .rugbyFootball: return "RUGBY FOOTBALL"
        case .womanSwimming: return "WOMAN SWIMMING"
        case .manSwimming: return "MAN SWIMMING"
        case .swimmer: return "SWIMMER"
        case .womanLiftingWeights: return "WOMAN LIFTING WEIGHTS"
        case .manLiftingWeights: return "MAN LIFTING WEIGHTS"
        case .personLiftingWeights: return "PERSON LIFTING WEIGHTS"
        case .womanGolfing: return "WOMAN GOLFING"
        case .manGolfing: return "MAN GOLFING"
        case .personGolfing: return "PERSON GOLFING"
        case .motorcycle: return "MOTORCYCLE"
        case .racingCar: return "RACING CAR"
        case .cricketBatAndBall: return "CRICKET BAT AND BALL"
        case .volleyball: return "VOLLEYBALL"
        case .fieldHockeyStickAndBall: return "FIELD HOCKEY STICK AND BALL"
        case .iceHockeyStickAndPuck: return "ICE HOCKEY STICK AND PUCK"
        case .tableTennisPaddleAndBall: return "TABLE TENNIS PADDLE AND BALL"
        case .snowcappedMountain: return "SNOW-CAPPED MOUNTAIN"
        case .camping: return "CAMPING"
        case .beachWithUmbrella: return "BEACH WITH UMBRELLA"
        case .buildingConstruction: return "BUILDING CONSTRUCTION"
        case .houses: return "HOUSES"
        case .cityscape: return "CITYSCAPE"
        case .derelictHouse: return "DERELICT HOUSE"
        case .classicalBuilding: return "CLASSICAL BUILDING"
        case .desert: return "DESERT"
        case .desertIsland: return "DESERT ISLAND"
        case .nationalPark: return "NATIONAL PARK"
        case .stadium: return "STADIUM"
        case .houseBuilding: return "HOUSE BUILDING"
        case .houseWithGarden: return "HOUSE WITH GARDEN"
        case .officeBuilding: return "OFFICE BUILDING"
        case .japanesePostOffice: return "JAPANESE POST OFFICE"
        case .europeanPostOffice: return "EUROPEAN POST OFFICE"
        case .hospital: return "HOSPITAL"
        case .bank: return "BANK"
        case .automatedTellerMachine: return "AUTOMATED TELLER MACHINE"
        case .hotel: return "HOTEL"
        case .loveHotel: return "LOVE HOTEL"
        case .convenienceStore: return "CONVENIENCE STORE"
        case .school: return "SCHOOL"
        case .departmentStore: return "DEPARTMENT STORE"
        case .factory: return "FACTORY"
        case .izakayaLantern: return "IZAKAYA LANTERN"
        case .japaneseCastle: return "JAPANESE CASTLE"
        case .europeanCastle: return "EUROPEAN CASTLE"
        case .rainbowFlag: return "RAINBOW FLAG"
        case .transgenderFlag: return "TRANSGENDER FLAG"
        case .whiteFlag: return "WHITE FLAG"
        case .pirateFlag: return "PIRATE FLAG"
        case .englandFlag: return "England Flag"
        case .scotlandFlag: return "Scotland Flag"
        case .walesFlag: return "Wales Flag"
        case .wavingBlackFlag: return "WAVING BLACK FLAG"
        case .rosette: return "ROSETTE"
        case .label: return "LABEL"
        case .badmintonRacquetAndShuttlecock: return "BADMINTON RACQUET AND SHUTTLECOCK"
        case .bowAndArrow: return "BOW AND ARROW"
        case .amphora: return "AMPHORA"
        case .emojiModifierFitzpatrickType12: return "EMOJI MODIFIER FITZPATRICK TYPE-1-2"
        case .emojiModifierFitzpatrickType3: return "EMOJI MODIFIER FITZPATRICK TYPE-3"
        case .emojiModifierFitzpatrickType4: return "EMOJI MODIFIER FITZPATRICK TYPE-4"
        case .emojiModifierFitzpatrickType5: return "EMOJI MODIFIER FITZPATRICK TYPE-5"
        case .emojiModifierFitzpatrickType6: return "EMOJI MODIFIER FITZPATRICK TYPE-6"
        case .rat: return "RAT"
        case .mouse: return "MOUSE"
        case .ox: return "OX"
        case .waterBuffalo: return "WATER BUFFALO"
        case .cow: return "COW"
        case .tiger: return "TIGER"
        case .leopard: return "LEOPARD"
        case .rabbit: return "RABBIT"
        case .blackCat: return "BLACK CAT"
        case .cat: return "CAT"
        case .dragon: return "DRAGON"
        case .crocodile: return "CROCODILE"
        case .whale: return "WHALE"
        case .snail: return "SNAIL"
        case .snake: return "SNAKE"
        case .horse: return "HORSE"
        case .ram: return "RAM"
        case .goat: return "GOAT"
        case .sheep: return "SHEEP"
        case .monkey: return "MONKEY"
        case .rooster: return "ROOSTER"
        case .chicken: return "CHICKEN"
        case .serviceDog: return "SERVICE DOG"
        case .dog: return "DOG"
        case .pig: return "PIG"
        case .boar: return "BOAR"
        case .elephant: return "ELEPHANT"
        case .octopus: return "OCTOPUS"
        case .spiralShell: return "SPIRAL SHELL"
        case .bug: return "BUG"
        case .ant: return "ANT"
        case .honeybee: return "HONEYBEE"
        case .ladyBeetle: return "LADY BEETLE"
        case .fish: return "FISH"
        case .tropicalFish: return "TROPICAL FISH"
        case .blowfish: return "BLOWFISH"
        case .turtle: return "TURTLE"
        case .hatchingChick: return "HATCHING CHICK"
        case .babyChick: return "BABY CHICK"
        case .frontfacingBabyChick: return "FRONT-FACING BABY CHICK"
        case .phoenix: return "PHOENIX"
        case .blackBird: return "BLACK BIRD"
        case .bird: return "BIRD"
        case .penguin: return "PENGUIN"
        case .koala: return "KOALA"
        case .poodle: return "POODLE"
        case .dromedaryCamel: return "DROMEDARY CAMEL"
        case .bactrianCamel: return "BACTRIAN CAMEL"
        case .dolphin: return "DOLPHIN"
        case .mouseFace: return "MOUSE FACE"
        case .cowFace: return "COW FACE"
        case .tigerFace: return "TIGER FACE"
        case .rabbitFace: return "RABBIT FACE"
        case .catFace: return "CAT FACE"
        case .dragonFace: return "DRAGON FACE"
        case .spoutingWhale: return "SPOUTING WHALE"
        case .horseFace: return "HORSE FACE"
        case .monkeyFace: return "MONKEY FACE"
        case .dogFace: return "DOG FACE"
        case .pigFace: return "PIG FACE"
        case .frogFace: return "FROG FACE"
        case .hamsterFace: return "HAMSTER FACE"
        case .wolfFace: return "WOLF FACE"
        case .polarBear: return "POLAR BEAR"
        case .bearFace: return "BEAR FACE"
        case .pandaFace: return "PANDA FACE"
        case .pigNose: return "PIG NOSE"
        case .pawPrints: return "PAW PRINTS"
        case .chipmunk: return "CHIPMUNK"
        case .eyes: return "EYES"
        case .eyeInSpeechBubble: return "EYE IN SPEECH BUBBLE"
        case .eye: return "EYE"
        case .ear: return "EAR"
        case .nose: return "NOSE"
        case .mouth: return "MOUTH"
        case .tongue: return "TONGUE"
        case .whiteUpPointingBackhandIndex: return "WHITE UP POINTING BACKHAND INDEX"
        case .whiteDownPointingBackhandIndex: return "WHITE DOWN POINTING BACKHAND INDEX"
        case .whiteLeftPointingBackhandIndex: return "WHITE LEFT POINTING BACKHAND INDEX"
        case .whiteRightPointingBackhandIndex: return "WHITE RIGHT POINTING BACKHAND INDEX"
        case .fistedHandSign: return "FISTED HAND SIGN"
        case .wavingHandSign: return "WAVING HAND SIGN"
        case .okHandSign: return "OK HAND SIGN"
        case .thumbsUpSign: return "THUMBS UP SIGN"
        case .thumbsDownSign: return "THUMBS DOWN SIGN"
        case .clappingHandsSign: return "CLAPPING HANDS SIGN"
        case .openHandsSign: return "OPEN HANDS SIGN"
        case .crown: return "CROWN"
        case .womansHat: return "WOMANS HAT"
        case .eyeglasses: return "EYEGLASSES"
        case .necktie: return "NECKTIE"
        case .tshirt: return "T-SHIRT"
        case .jeans: return "JEANS"
        case .dress: return "DRESS"
        case .kimono: return "KIMONO"
        case .bikini: return "BIKINI"
        case .womansClothes: return "WOMANS CLOTHES"
        case .purse: return "PURSE"
        case .handbag: return "HANDBAG"
        case .pouch: return "POUCH"
        case .mansShoe: return "MANS SHOE"
        case .athleticShoe: return "ATHLETIC SHOE"
        case .highheeledShoe: return "HIGH-HEELED SHOE"
        case .womansSandal: return "WOMANS SANDAL"
        case .womansBoots: return "WOMANS BOOTS"
        case .footprints: return "FOOTPRINTS"
        case .bustInSilhouette: return "BUST IN SILHOUETTE"
        case .bustsInSilhouette: return "BUSTS IN SILHOUETTE"
        case .boy: return "BOY"
        case .girl: return "GIRL"
        case .manFarmer: return "MAN FARMER"
        case .manCook: return "MAN COOK"
        case .manFeedingBaby: return "MAN FEEDING BABY"
        case .manStudent: return "MAN STUDENT"
        case .manSinger: return "MAN SINGER"
        case .manArtist: return "MAN ARTIST"
        case .manTeacher: return "MAN TEACHER"
        case .manFactoryWorker: return "MAN FACTORY WORKER"
        case .familyManBoyBoy: return "FAMILY: MAN, BOY, BOY"
        case .familyManBoy: return "FAMILY: MAN, BOY"
        case .familyManGirlBoy: return "FAMILY: MAN, GIRL, BOY"
        case .familyManGirlGirl: return "FAMILY: MAN, GIRL, GIRL"
        case .familyManGirl: return "FAMILY: MAN, GIRL"
        case .familyManManBoy: return "FAMILY: MAN, MAN, BOY"
        case .familyManManBoyBoy: return "FAMILY: MAN, MAN, BOY, BOY"
        case .familyManManGirl: return "FAMILY: MAN, MAN, GIRL"
        case .familyManManGirlBoy: return "FAMILY: MAN, MAN, GIRL, BOY"
        case .familyManManGirlGirl: return "FAMILY: MAN, MAN, GIRL, GIRL"
        case .familyManWomanBoy: return "FAMILY: MAN, WOMAN, BOY"
        case .familyManWomanBoyBoy: return "FAMILY: MAN, WOMAN, BOY, BOY"
        case .familyManWomanGirl: return "FAMILY: MAN, WOMAN, GIRL"
        case .familyManWomanGirlBoy: return "FAMILY: MAN, WOMAN, GIRL, BOY"
        case .familyManWomanGirlGirl: return "FAMILY: MAN, WOMAN, GIRL, GIRL"
        case .manTechnologist: return "MAN TECHNOLOGIST"
        case .manOfficeWorker: return "MAN OFFICE WORKER"
        case .manMechanic: return "MAN MECHANIC"
        case .manScientist: return "MAN SCIENTIST"
        case .manAstronaut: return "MAN ASTRONAUT"
        case .manFirefighter: return "MAN FIREFIGHTER"
        case .manWithWhiteCaneFacingRight: return "MAN WITH WHITE CANE FACING RIGHT"
        case .manWithWhiteCane: return "MAN WITH WHITE CANE"
        case .manRedHair: return "MAN: RED HAIR"
        case .manCurlyHair: return "MAN: CURLY HAIR"
        case .manBald: return "MAN: BALD"
        case .manWhiteHair: return "MAN: WHITE HAIR"
        case .manInMotorizedWheelchairFacingRight: return "MAN IN MOTORIZED WHEELCHAIR FACING RIGHT"
        case .manInMotorizedWheelchair: return "MAN IN MOTORIZED WHEELCHAIR"
        case .manInManualWheelchairFacingRight: return "MAN IN MANUAL WHEELCHAIR FACING RIGHT"
        case .manInManualWheelchair: return "MAN IN MANUAL WHEELCHAIR"
        case .manHealthWorker: return "MAN HEALTH WORKER"
        case .manJudge: return "MAN JUDGE"
        case .manPilot: return "MAN PILOT"
        case .coupleWithHeartManMan: return "COUPLE WITH HEART: MAN, MAN"
        case .kissManMan: return "KISS: MAN, MAN"
        case .man: return "MAN"
        case .womanFarmer: return "WOMAN FARMER"
        case .womanCook: return "WOMAN COOK"
        case .womanFeedingBaby: return "WOMAN FEEDING BABY"
        case .womanStudent: return "WOMAN STUDENT"
        case .womanSinger: return "WOMAN SINGER"
        case .womanArtist: return "WOMAN ARTIST"
        case .womanTeacher: return "WOMAN TEACHER"
        case .womanFactoryWorker: return "WOMAN FACTORY WORKER"
        case .familyWomanBoyBoy: return "FAMILY: WOMAN, BOY, BOY"
        case .familyWomanBoy: return "FAMILY: WOMAN, BOY"
        case .familyWomanGirlBoy: return "FAMILY: WOMAN, GIRL, BOY"
        case .familyWomanGirlGirl: return "FAMILY: WOMAN, GIRL, GIRL"
        case .familyWomanGirl: return "FAMILY: WOMAN, GIRL"
        case .familyWomanWomanBoy: return "FAMILY: WOMAN, WOMAN, BOY"
        case .familyWomanWomanBoyBoy: return "FAMILY: WOMAN, WOMAN, BOY, BOY"
        case .familyWomanWomanGirl: return "FAMILY: WOMAN, WOMAN, GIRL"
        case .familyWomanWomanGirlBoy: return "FAMILY: WOMAN, WOMAN, GIRL, BOY"
        case .familyWomanWomanGirlGirl: return "FAMILY: WOMAN, WOMAN, GIRL, GIRL"
        case .womanTechnologist: return "WOMAN TECHNOLOGIST"
        case .womanOfficeWorker: return "WOMAN OFFICE WORKER"
        case .womanMechanic: return "WOMAN MECHANIC"
        case .womanScientist: return "WOMAN SCIENTIST"
        case .womanAstronaut: return "WOMAN ASTRONAUT"
        case .womanFirefighter: return "WOMAN FIREFIGHTER"
        case .womanWithWhiteCaneFacingRight: return "WOMAN WITH WHITE CANE FACING RIGHT"
        case .womanWithWhiteCane: return "WOMAN WITH WHITE CANE"
        case .womanRedHair: return "WOMAN: RED HAIR"
        case .womanCurlyHair: return "WOMAN: CURLY HAIR"
        case .womanBald: return "WOMAN: BALD"
        case .womanWhiteHair: return "WOMAN: WHITE HAIR"
        case .womanInMotorizedWheelchairFacingRight: return "WOMAN IN MOTORIZED WHEELCHAIR FACING RIGHT"
        case .womanInMotorizedWheelchair: return "WOMAN IN MOTORIZED WHEELCHAIR"
        case .womanInManualWheelchairFacingRight: return "WOMAN IN MANUAL WHEELCHAIR FACING RIGHT"
        case .womanInManualWheelchair: return "WOMAN IN MANUAL WHEELCHAIR"
        case .womanHealthWorker: return "WOMAN HEALTH WORKER"
        case .womanJudge: return "WOMAN JUDGE"
        case .womanPilot: return "WOMAN PILOT"
        case .coupleWithHeartWomanMan: return "COUPLE WITH HEART: WOMAN, MAN"
        case .coupleWithHeartWomanWoman: return "COUPLE WITH HEART: WOMAN, WOMAN"
        case .kissWomanMan: return "KISS: WOMAN, MAN"
        case .kissWomanWoman: return "KISS: WOMAN, WOMAN"
        case .woman: return "WOMAN"
        case .family: return "FAMILY"
        case .manAndWomanHoldingHands: return "MAN AND WOMAN HOLDING HANDS"
        case .twoMenHoldingHands: return "TWO MEN HOLDING HANDS"
        case .twoWomenHoldingHands: return "TWO WOMEN HOLDING HANDS"
        case .womanPoliceOfficer: return "WOMAN POLICE OFFICER"
        case .manPoliceOfficer: return "MAN POLICE OFFICER"
        case .policeOfficer: return "POLICE OFFICER"
        case .womenWithBunnyEars: return "WOMEN WITH BUNNY EARS"
        case .menWithBunnyEars: return "MEN WITH BUNNY EARS"
        case .womanWithBunnyEars: return "WOMAN WITH BUNNY EARS"
        case .womanWithVeil: return "WOMAN WITH VEIL"
        case .manWithVeil: return "MAN WITH VEIL"
        case .brideWithVeil: return "BRIDE WITH VEIL"
        case .womanBlondHair: return "WOMAN: BLOND HAIR"
        case .manBlondHair: return "MAN: BLOND HAIR"
        case .personWithBlondHair: return "PERSON WITH BLOND HAIR"
        case .manWithGuaPiMao: return "MAN WITH GUA PI MAO"
        case .womanWearingTurban: return "WOMAN WEARING TURBAN"
        case .manWearingTurban: return "MAN WEARING TURBAN"
        case .manWithTurban: return "MAN WITH TURBAN"
        case .olderMan: return "OLDER MAN"
        case .olderWoman: return "OLDER WOMAN"
        case .baby: return "BABY"
        case .womanConstructionWorker: return "WOMAN CONSTRUCTION WORKER"
        case .manConstructionWorker: return "MAN CONSTRUCTION WORKER"
        case .constructionWorker: return "CONSTRUCTION WORKER"
        case .princess: return "PRINCESS"
        case .japaneseOgre: return "JAPANESE OGRE"
        case .japaneseGoblin: return "JAPANESE GOBLIN"
        case .ghost: return "GHOST"
        case .babyAngel: return "BABY ANGEL"
        case .extraterrestrialAlien: return "EXTRATERRESTRIAL ALIEN"
        case .alienMonster: return "ALIEN MONSTER"
        case .imp: return "IMP"
        case .skull: return "SKULL"
        case .womanTippingHand: return "WOMAN TIPPING HAND"
        case .manTippingHand: return "MAN TIPPING HAND"
        case .informationDeskPerson: return "INFORMATION DESK PERSON"
        case .womanGuard: return "WOMAN GUARD"
        case .manGuard: return "MAN GUARD"
        case .guardsman: return "GUARDSMAN"
        case .dancer: return "DANCER"
        case .lipstick: return "LIPSTICK"
        case .nailPolish: return "NAIL POLISH"
        case .womanGettingMassage: return "WOMAN GETTING MASSAGE"
        case .manGettingMassage: return "MAN GETTING MASSAGE"
        case .faceMassage: return "FACE MASSAGE"
        case .womanGettingHaircut: return "WOMAN GETTING HAIRCUT"
        case .manGettingHaircut: return "MAN GETTING HAIRCUT"
        case .haircut: return "HAIRCUT"
        case .barberPole: return "BARBER POLE"
        case .syringe: return "SYRINGE"
        case .pill: return "PILL"
        case .kissMark: return "KISS MARK"
        case .loveLetter: return "LOVE LETTER"
        case .ring: return "RING"
        case .gemStone: return "GEM STONE"
        case .kiss: return "KISS"
        case .bouquet: return "BOUQUET"
        case .coupleWithHeart: return "COUPLE WITH HEART"
        case .wedding: return "WEDDING"
        case .beatingHeart: return "BEATING HEART"
        case .brokenHeart: return "BROKEN HEART"
        case .twoHearts: return "TWO HEARTS"
        case .sparklingHeart: return "SPARKLING HEART"
        case .growingHeart: return "GROWING HEART"
        case .heartWithArrow: return "HEART WITH ARROW"
        case .blueHeart: return "BLUE HEART"
        case .greenHeart: return "GREEN HEART"
        case .yellowHeart: return "YELLOW HEART"
        case .purpleHeart: return "PURPLE HEART"
        case .heartWithRibbon: return "HEART WITH RIBBON"
        case .revolvingHearts: return "REVOLVING HEARTS"
        case .heartDecoration: return "HEART DECORATION"
        case .diamondShapeWithADotInside: return "DIAMOND SHAPE WITH A DOT INSIDE"
        case .electricLightBulb: return "ELECTRIC LIGHT BULB"
        case .angerSymbol: return "ANGER SYMBOL"
        case .bomb: return "BOMB"
        case .sleepingSymbol: return "SLEEPING SYMBOL"
        case .collisionSymbol: return "COLLISION SYMBOL"
        case .splashingSweatSymbol: return "SPLASHING SWEAT SYMBOL"
        case .droplet: return "DROPLET"
        case .dashSymbol: return "DASH SYMBOL"
        case .pileOfPoo: return "PILE OF POO"
        case .flexedBiceps: return "FLEXED BICEPS"
        case .dizzySymbol: return "DIZZY SYMBOL"
        case .speechBalloon: return "SPEECH BALLOON"
        case .thoughtBalloon: return "THOUGHT BALLOON"
        case .whiteFlower: return "WHITE FLOWER"
        case .hundredPointsSymbol: return "HUNDRED POINTS SYMBOL"
        case .moneyBag: return "MONEY BAG"
        case .currencyExchange: return "CURRENCY EXCHANGE"
        case .heavyDollarSign: return "HEAVY DOLLAR SIGN"
        case .creditCard: return "CREDIT CARD"
        case .banknoteWithYenSign: return "BANKNOTE WITH YEN SIGN"
        case .banknoteWithDollarSign: return "BANKNOTE WITH DOLLAR SIGN"
        case .banknoteWithEuroSign: return "BANKNOTE WITH EURO SIGN"
        case .banknoteWithPoundSign: return "BANKNOTE WITH POUND SIGN"
        case .moneyWithWings: return "MONEY WITH WINGS"
        case .chartWithUpwardsTrendAndYenSign: return "CHART WITH UPWARDS TREND AND YEN SIGN"
        case .seat: return "SEAT"
        case .personalComputer: return "PERSONAL COMPUTER"
        case .briefcase: return "BRIEFCASE"
        case .minidisc: return "MINIDISC"
        case .floppyDisk: return "FLOPPY DISK"
        case .opticalDisc: return "OPTICAL DISC"
        case .dvd: return "DVD"
        case .fileFolder: return "FILE FOLDER"
        case .openFileFolder: return "OPEN FILE FOLDER"
        case .pageWithCurl: return "PAGE WITH CURL"
        case .pageFacingUp: return "PAGE FACING UP"
        case .calendar: return "CALENDAR"
        case .tearoffCalendar: return "TEAR-OFF CALENDAR"
        case .cardIndex: return "CARD INDEX"
        case .chartWithUpwardsTrend: return "CHART WITH UPWARDS TREND"
        case .chartWithDownwardsTrend: return "CHART WITH DOWNWARDS TREND"
        case .barChart: return "BAR CHART"
        case .clipboard: return "CLIPBOARD"
        case .pushpin: return "PUSHPIN"
        case .roundPushpin: return "ROUND PUSHPIN"
        case .paperclip: return "PAPERCLIP"
        case .straightRuler: return "STRAIGHT RULER"
        case .triangularRuler: return "TRIANGULAR RULER"
        case .bookmarkTabs: return "BOOKMARK TABS"
        case .ledger: return "LEDGER"
        case .notebook: return "NOTEBOOK"
        case .notebookWithDecorativeCover: return "NOTEBOOK WITH DECORATIVE COVER"
        case .closedBook: return "CLOSED BOOK"
        case .openBook: return "OPEN BOOK"
        case .greenBook: return "GREEN BOOK"
        case .blueBook: return "BLUE BOOK"
        case .orangeBook: return "ORANGE BOOK"
        case .books: return "BOOKS"
        case .nameBadge: return "NAME BADGE"
        case .scroll: return "SCROLL"
        case .memo: return "MEMO"
        case .telephoneReceiver: return "TELEPHONE RECEIVER"
        case .pager: return "PAGER"
        case .faxMachine: return "FAX MACHINE"
        case .satelliteAntenna: return "SATELLITE ANTENNA"
        case .publicAddressLoudspeaker: return "PUBLIC ADDRESS LOUDSPEAKER"
        case .cheeringMegaphone: return "CHEERING MEGAPHONE"
        case .outboxTray: return "OUTBOX TRAY"
        case .inboxTray: return "INBOX TRAY"
        case .package: return "PACKAGE"
        case .emailSymbol: return "E-MAIL SYMBOL"
        case .incomingEnvelope: return "INCOMING ENVELOPE"
        case .envelopeWithDownwardsArrowAbove: return "ENVELOPE WITH DOWNWARDS ARROW ABOVE"
        case .closedMailboxWithLoweredFlag: return "CLOSED MAILBOX WITH LOWERED FLAG"
        case .closedMailboxWithRaisedFlag: return "CLOSED MAILBOX WITH RAISED FLAG"
        case .openMailboxWithRaisedFlag: return "OPEN MAILBOX WITH RAISED FLAG"
        case .openMailboxWithLoweredFlag: return "OPEN MAILBOX WITH LOWERED FLAG"
        case .postbox: return "POSTBOX"
        case .postalHorn: return "POSTAL HORN"
        case .newspaper: return "NEWSPAPER"
        case .mobilePhone: return "MOBILE PHONE"
        case .mobilePhoneWithRightwardsArrowAtLeft: return "MOBILE PHONE WITH RIGHTWARDS ARROW AT LEFT"
        case .vibrationMode: return "VIBRATION MODE"
        case .mobilePhoneOff: return "MOBILE PHONE OFF"
        case .noMobilePhones: return "NO MOBILE PHONES"
        case .antennaWithBars: return "ANTENNA WITH BARS"
        case .camera: return "CAMERA"
        case .cameraWithFlash: return "CAMERA WITH FLASH"
        case .videoCamera: return "VIDEO CAMERA"
        case .television: return "TELEVISION"
        case .radio: return "RADIO"
        case .videocassette: return "VIDEOCASSETTE"
        case .filmProjector: return "FILM PROJECTOR"
        case .prayerBeads: return "PRAYER BEADS"
        case .twistedRightwardsArrows: return "TWISTED RIGHTWARDS ARROWS"
        case .clockwiseRightwardsAndLeftwardsOpenCircleArrows: return "CLOCKWISE RIGHTWARDS AND LEFTWARDS OPEN CIRCLE ARROWS"
        case .clockwiseRightwardsAndLeftwardsOpenCircleArrowsWithCircledOneOverlay: return "CLOCKWISE RIGHTWARDS AND LEFTWARDS OPEN CIRCLE ARROWS WITH CIRCLED ONE OVERLAY"
        case .clockwiseDownwardsAndUpwardsOpenCircleArrows: return "CLOCKWISE DOWNWARDS AND UPWARDS OPEN CIRCLE ARROWS"
        case .anticlockwiseDownwardsAndUpwardsOpenCircleArrows: return "ANTICLOCKWISE DOWNWARDS AND UPWARDS OPEN CIRCLE ARROWS"
        case .lowBrightnessSymbol: return "LOW BRIGHTNESS SYMBOL"
        case .highBrightnessSymbol: return "HIGH BRIGHTNESS SYMBOL"
        case .speakerWithCancellationStroke: return "SPEAKER WITH CANCELLATION STROKE"
        case .speaker: return "SPEAKER"
        case .speakerWithOneSoundWave: return "SPEAKER WITH ONE SOUND WAVE"
        case .speakerWithThreeSoundWaves: return "SPEAKER WITH THREE SOUND WAVES"
        case .battery: return "BATTERY"
        case .electricPlug: return "ELECTRIC PLUG"
        case .leftpointingMagnifyingGlass: return "LEFT-POINTING MAGNIFYING GLASS"
        case .rightpointingMagnifyingGlass: return "RIGHT-POINTING MAGNIFYING GLASS"
        case .lockWithInkPen: return "LOCK WITH INK PEN"
        case .closedLockWithKey: return "CLOSED LOCK WITH KEY"
        case .key: return "KEY"
        case .lock: return "LOCK"
        case .openLock: return "OPEN LOCK"
        case .bell: return "BELL"
        case .bellWithCancellationStroke: return "BELL WITH CANCELLATION STROKE"
        case .bookmark: return "BOOKMARK"
        case .linkSymbol: return "LINK SYMBOL"
        case .radioButton: return "RADIO BUTTON"
        case .backWithLeftwardsArrowAbove: return "BACK WITH LEFTWARDS ARROW ABOVE"
        case .endWithLeftwardsArrowAbove: return "END WITH LEFTWARDS ARROW ABOVE"
        case .onWithExclamationMarkWithLeftRightArrowAbove: return "ON WITH EXCLAMATION MARK WITH LEFT RIGHT ARROW ABOVE"
        case .soonWithRightwardsArrowAbove: return "SOON WITH RIGHTWARDS ARROW ABOVE"
        case .topWithUpwardsArrowAbove: return "TOP WITH UPWARDS ARROW ABOVE"
        case .noOneUnderEighteenSymbol: return "NO ONE UNDER EIGHTEEN SYMBOL"
        case .keycapTen: return "KEYCAP TEN"
        case .inputSymbolForLatinCapitalLetters: return "INPUT SYMBOL FOR LATIN CAPITAL LETTERS"
        case .inputSymbolForLatinSmallLetters: return "INPUT SYMBOL FOR LATIN SMALL LETTERS"
        case .inputSymbolForNumbers: return "INPUT SYMBOL FOR NUMBERS"
        case .inputSymbolForSymbols: return "INPUT SYMBOL FOR SYMBOLS"
        case .inputSymbolForLatinLetters: return "INPUT SYMBOL FOR LATIN LETTERS"
        case .fire: return "FIRE"
        case .electricTorch: return "ELECTRIC TORCH"
        case .wrench: return "WRENCH"
        case .hammer: return "HAMMER"
        case .nutAndBolt: return "NUT AND BOLT"
        case .hocho: return "HOCHO"
        case .pistol: return "PISTOL"
        case .microscope: return "MICROSCOPE"
        case .telescope: return "TELESCOPE"
        case .crystalBall: return "CRYSTAL BALL"
        case .sixPointedStarWithMiddleDot: return "SIX POINTED STAR WITH MIDDLE DOT"
        case .japaneseSymbolForBeginner: return "JAPANESE SYMBOL FOR BEGINNER"
        case .tridentEmblem: return "TRIDENT EMBLEM"
        case .blackSquareButton: return "BLACK SQUARE BUTTON"
        case .whiteSquareButton: return "WHITE SQUARE BUTTON"
        case .largeRedCircle: return "LARGE RED CIRCLE"
        case .largeBlueCircle: return "LARGE BLUE CIRCLE"
        case .largeOrangeDiamond: return "LARGE ORANGE DIAMOND"
        case .largeBlueDiamond: return "LARGE BLUE DIAMOND"
        case .smallOrangeDiamond: return "SMALL ORANGE DIAMOND"
        case .smallBlueDiamond: return "SMALL BLUE DIAMOND"
        case .uppointingRedTriangle: return "UP-POINTING RED TRIANGLE"
        case .downpointingRedTriangle: return "DOWN-POINTING RED TRIANGLE"
        case .uppointingSmallRedTriangle: return "UP-POINTING SMALL RED TRIANGLE"
        case .downpointingSmallRedTriangle: return "DOWN-POINTING SMALL RED TRIANGLE"
        case .om: return "OM"
        case .dove: return "DOVE"
        case .kaaba: return "KAABA"
        case .mosque: return "MOSQUE"
        case .synagogue: return "SYNAGOGUE"
        case .menorahWithNineBranches: return "MENORAH WITH NINE BRANCHES"
        case .clockFaceOneOclock: return "CLOCK FACE ONE OCLOCK"
        case .clockFaceTwoOclock: return "CLOCK FACE TWO OCLOCK"
        case .clockFaceThreeOclock: return "CLOCK FACE THREE OCLOCK"
        case .clockFaceFourOclock: return "CLOCK FACE FOUR OCLOCK"
        case .clockFaceFiveOclock: return "CLOCK FACE FIVE OCLOCK"
        case .clockFaceSixOclock: return "CLOCK FACE SIX OCLOCK"
        case .clockFaceSevenOclock: return "CLOCK FACE SEVEN OCLOCK"
        case .clockFaceEightOclock: return "CLOCK FACE EIGHT OCLOCK"
        case .clockFaceNineOclock: return "CLOCK FACE NINE OCLOCK"
        case .clockFaceTenOclock: return "CLOCK FACE TEN OCLOCK"
        case .clockFaceElevenOclock: return "CLOCK FACE ELEVEN OCLOCK"
        case .clockFaceTwelveOclock: return "CLOCK FACE TWELVE OCLOCK"
        case .clockFaceOnethirty: return "CLOCK FACE ONE-THIRTY"
        case .clockFaceTwothirty: return "CLOCK FACE TWO-THIRTY"
        case .clockFaceThreethirty: return "CLOCK FACE THREE-THIRTY"
        case .clockFaceFourthirty: return "CLOCK FACE FOUR-THIRTY"
        case .clockFaceFivethirty: return "CLOCK FACE FIVE-THIRTY"
        case .clockFaceSixthirty: return "CLOCK FACE SIX-THIRTY"
        case .clockFaceSeventhirty: return "CLOCK FACE SEVEN-THIRTY"
        case .clockFaceEightthirty: return "CLOCK FACE EIGHT-THIRTY"
        case .clockFaceNinethirty: return "CLOCK FACE NINE-THIRTY"
        case .clockFaceTenthirty: return "CLOCK FACE TEN-THIRTY"
        case .clockFaceEleventhirty: return "CLOCK FACE ELEVEN-THIRTY"
        case .clockFaceTwelvethirty: return "CLOCK FACE TWELVE-THIRTY"
        case .candle: return "CANDLE"
        case .mantelpieceClock: return "MANTELPIECE CLOCK"
        case .hole: return "HOLE"
        case .personInSuitLevitating: return "PERSON IN SUIT LEVITATING"
        case .womanDetective: return "WOMAN DETECTIVE"
        case .manDetective: return "MAN DETECTIVE"
        case .detective: return "DETECTIVE"
        case .sunglasses: return "SUNGLASSES"
        case .spider: return "SPIDER"
        case .spiderWeb: return "SPIDER WEB"
        case .joystick: return "JOYSTICK"
        case .manDancing: return "MAN DANCING"
        case .linkedPaperclips: return "LINKED PAPERCLIPS"
        case .pen: return "PEN"
        case .fountainPen: return "FOUNTAIN PEN"
        case .paintbrush: return "PAINTBRUSH"
        case .crayon: return "CRAYON"
        case .handWithFingersSplayed: return "HAND WITH FINGERS SPLAYED"
        case .reversedHandWithMiddleFingerExtended: return "REVERSED HAND WITH MIDDLE FINGER EXTENDED"
        case .raisedHandWithPartBetweenMiddleAndRingFingers: return "RAISED HAND WITH PART BETWEEN MIDDLE AND RING FINGERS"
        case .blackHeart: return "BLACK HEART"
        case .desktopComputer: return "DESKTOP COMPUTER"
        case .printer: return "PRINTER"
        case .computerMouse: return "COMPUTER MOUSE"
        case .trackball: return "TRACKBALL"
        case .framedPicture: return "FRAMED PICTURE"
        case .cardIndexDividers: return "CARD INDEX DIVIDERS"
        case .cardFileBox: return "CARD FILE BOX"
        case .fileCabinet: return "FILE CABINET"
        case .wastebasket: return "WASTEBASKET"
        case .spiralNotepad: return "SPIRAL NOTEPAD"
        case .spiralCalendar: return "SPIRAL CALENDAR"
        case .clamp: return "CLAMP"
        case .oldKey: return "OLD KEY"
        case .rolledupNewspaper: return "ROLLED-UP NEWSPAPER"
        case .dagger: return "DAGGER"
        case .speakingHead: return "SPEAKING HEAD"
        case .leftSpeechBubble: return "LEFT SPEECH BUBBLE"
        case .rightAngerBubble: return "RIGHT ANGER BUBBLE"
        case .ballotBoxWithBallot: return "BALLOT BOX WITH BALLOT"
        case .worldMap: return "WORLD MAP"
        case .mountFuji: return "MOUNT FUJI"
        case .tokyoTower: return "TOKYO TOWER"
        case .statueOfLiberty: return "STATUE OF LIBERTY"
        case .silhouetteOfJapan: return "SILHOUETTE OF JAPAN"
        case .moyai: return "MOYAI"
        case .grinningFace: return "GRINNING FACE"
        case .grinningFaceWithSmilingEyes: return "GRINNING FACE WITH SMILING EYES"
        case .faceWithTearsOfJoy: return "FACE WITH TEARS OF JOY"
        case .smilingFaceWithOpenMouth: return "SMILING FACE WITH OPEN MOUTH"
        case .smilingFaceWithOpenMouthAndSmilingEyes: return "SMILING FACE WITH OPEN MOUTH AND SMILING EYES"
        case .smilingFaceWithOpenMouthAndColdSweat: return "SMILING FACE WITH OPEN MOUTH AND COLD SWEAT"
        case .smilingFaceWithOpenMouthAndTightlyclosedEyes: return "SMILING FACE WITH OPEN MOUTH AND TIGHTLY-CLOSED EYES"
        case .smilingFaceWithHalo: return "SMILING FACE WITH HALO"
        case .smilingFaceWithHorns: return "SMILING FACE WITH HORNS"
        case .winkingFace: return "WINKING FACE"
        case .smilingFaceWithSmilingEyes: return "SMILING FACE WITH SMILING EYES"
        case .faceSavouringDeliciousFood: return "FACE SAVOURING DELICIOUS FOOD"
        case .relievedFace: return "RELIEVED FACE"
        case .smilingFaceWithHeartshapedEyes: return "SMILING FACE WITH HEART-SHAPED EYES"
        case .smilingFaceWithSunglasses: return "SMILING FACE WITH SUNGLASSES"
        case .smirkingFace: return "SMIRKING FACE"
        case .neutralFace: return "NEUTRAL FACE"
        case .expressionlessFace: return "EXPRESSIONLESS FACE"
        case .unamusedFace: return "UNAMUSED FACE"
        case .faceWithColdSweat: return "FACE WITH COLD SWEAT"
        case .pensiveFace: return "PENSIVE FACE"
        case .confusedFace: return "CONFUSED FACE"
        case .confoundedFace: return "CONFOUNDED FACE"
        case .kissingFace: return "KISSING FACE"
        case .faceThrowingAKiss: return "FACE THROWING A KISS"
        case .kissingFaceWithSmilingEyes: return "KISSING FACE WITH SMILING EYES"
        case .kissingFaceWithClosedEyes: return "KISSING FACE WITH CLOSED EYES"
        case .faceWithStuckoutTongue: return "FACE WITH STUCK-OUT TONGUE"
        case .faceWithStuckoutTongueAndWinkingEye: return "FACE WITH STUCK-OUT TONGUE AND WINKING EYE"
        case .faceWithStuckoutTongueAndTightlyclosedEyes: return "FACE WITH STUCK-OUT TONGUE AND TIGHTLY-CLOSED EYES"
        case .disappointedFace: return "DISAPPOINTED FACE"
        case .worriedFace: return "WORRIED FACE"
        case .angryFace: return "ANGRY FACE"
        case .poutingFace: return "POUTING FACE"
        case .cryingFace: return "CRYING FACE"
        case .perseveringFace: return "PERSEVERING FACE"
        case .faceWithLookOfTriumph: return "FACE WITH LOOK OF TRIUMPH"
        case .disappointedButRelievedFace: return "DISAPPOINTED BUT RELIEVED FACE"
        case .frowningFaceWithOpenMouth: return "FROWNING FACE WITH OPEN MOUTH"
        case .anguishedFace: return "ANGUISHED FACE"
        case .fearfulFace: return "FEARFUL FACE"
        case .wearyFace: return "WEARY FACE"
        case .sleepyFace: return "SLEEPY FACE"
        case .tiredFace: return "TIRED FACE"
        case .grimacingFace: return "GRIMACING FACE"
        case .loudlyCryingFace: return "LOUDLY CRYING FACE"
        case .faceExhaling: return "FACE EXHALING"
        case .faceWithOpenMouth: return "FACE WITH OPEN MOUTH"
        case .hushedFace: return "HUSHED FACE"
        case .faceWithOpenMouthAndColdSweat: return "FACE WITH OPEN MOUTH AND COLD SWEAT"
        case .faceScreamingInFear: return "FACE SCREAMING IN FEAR"
        case .astonishedFace: return "ASTONISHED FACE"
        case .flushedFace: return "FLUSHED FACE"
        case .sleepingFace: return "SLEEPING FACE"
        case .faceWithSpiralEyes: return "FACE WITH SPIRAL EYES"
        case .dizzyFace: return "DIZZY FACE"
        case .faceInClouds: return "FACE IN CLOUDS"
        case .faceWithoutMouth: return "FACE WITHOUT MOUTH"
        case .faceWithMedicalMask: return "FACE WITH MEDICAL MASK"
        case .grinningCatFaceWithSmilingEyes: return "GRINNING CAT FACE WITH SMILING EYES"
        case .catFaceWithTearsOfJoy: return "CAT FACE WITH TEARS OF JOY"
        case .smilingCatFaceWithOpenMouth: return "SMILING CAT FACE WITH OPEN MOUTH"
        case .smilingCatFaceWithHeartshapedEyes: return "SMILING CAT FACE WITH HEART-SHAPED EYES"
        case .catFaceWithWrySmile: return "CAT FACE WITH WRY SMILE"
        case .kissingCatFaceWithClosedEyes: return "KISSING CAT FACE WITH CLOSED EYES"
        case .poutingCatFace: return "POUTING CAT FACE"
        case .cryingCatFace: return "CRYING CAT FACE"
        case .wearyCatFace: return "WEARY CAT FACE"
        case .slightlyFrowningFace: return "SLIGHTLY FROWNING FACE"
        case .headShakingHorizontally: return "HEAD SHAKING HORIZONTALLY"
        case .headShakingVertically: return "HEAD SHAKING VERTICALLY"
        case .slightlySmilingFace: return "SLIGHTLY SMILING FACE"
        case .upsidedownFace: return "UPSIDE-DOWN FACE"
        case .faceWithRollingEyes: return "FACE WITH ROLLING EYES"
        case .womanGesturingNo: return "WOMAN GESTURING NO"
        case .manGesturingNo: return "MAN GESTURING NO"
        case .faceWithNoGoodGesture: return "FACE WITH NO GOOD GESTURE"
        case .womanGesturingOk: return "WOMAN GESTURING OK"
        case .manGesturingOk: return "MAN GESTURING OK"
        case .faceWithOkGesture: return "FACE WITH OK GESTURE"
        case .womanBowing: return "WOMAN BOWING"
        case .manBowing: return "MAN BOWING"
        case .personBowingDeeply: return "PERSON BOWING DEEPLY"
        case .seenoevilMonkey: return "SEE-NO-EVIL MONKEY"
        case .hearnoevilMonkey: return "HEAR-NO-EVIL MONKEY"
        case .speaknoevilMonkey: return "SPEAK-NO-EVIL MONKEY"
        case .womanRaisingHand: return "WOMAN RAISING HAND"
        case .manRaisingHand: return "MAN RAISING HAND"
        case .happyPersonRaisingOneHand: return "HAPPY PERSON RAISING ONE HAND"
        case .personRaisingBothHandsInCelebration: return "PERSON RAISING BOTH HANDS IN CELEBRATION"
        case .womanFrowning: return "WOMAN FROWNING"
        case .manFrowning: return "MAN FROWNING"
        case .personFrowning: return "PERSON FROWNING"
        case .womanPouting: return "WOMAN POUTING"
        case .manPouting: return "MAN POUTING"
        case .personWithPoutingFace: return "PERSON WITH POUTING FACE"
        case .personWithFoldedHands: return "PERSON WITH FOLDED HANDS"
        case .rocket: return "ROCKET"
        case .helicopter: return "HELICOPTER"
        case .steamLocomotive: return "STEAM LOCOMOTIVE"
        case .railwayCar: return "RAILWAY CAR"
        case .highspeedTrain: return "HIGH-SPEED TRAIN"
        case .highspeedTrainWithBulletNose: return "HIGH-SPEED TRAIN WITH BULLET NOSE"
        case .train: return "TRAIN"
        case .metro: return "METRO"
        case .lightRail: return "LIGHT RAIL"
        case .station: return "STATION"
        case .tram: return "TRAM"
        case .tramCar: return "TRAM CAR"
        case .bus: return "BUS"
        case .oncomingBus: return "ONCOMING BUS"
        case .trolleybus: return "TROLLEYBUS"
        case .busStop: return "BUS STOP"
        case .minibus: return "MINIBUS"
        case .ambulance: return "AMBULANCE"
        case .fireEngine: return "FIRE ENGINE"
        case .policeCar: return "POLICE CAR"
        case .oncomingPoliceCar: return "ONCOMING POLICE CAR"
        case .taxi: return "TAXI"
        case .oncomingTaxi: return "ONCOMING TAXI"
        case .automobile: return "AUTOMOBILE"
        case .oncomingAutomobile: return "ONCOMING AUTOMOBILE"
        case .recreationalVehicle: return "RECREATIONAL VEHICLE"
        case .deliveryTruck: return "DELIVERY TRUCK"
        case .articulatedLorry: return "ARTICULATED LORRY"
        case .tractor: return "TRACTOR"
        case .monorail: return "MONORAIL"
        case .mountainRailway: return "MOUNTAIN RAILWAY"
        case .suspensionRailway: return "SUSPENSION RAILWAY"
        case .mountainCableway: return "MOUNTAIN CABLEWAY"
        case .aerialTramway: return "AERIAL TRAMWAY"
        case .ship: return "SHIP"
        case .womanRowingBoat: return "WOMAN ROWING BOAT"
        case .manRowingBoat: return "MAN ROWING BOAT"
        case .rowboat: return "ROWBOAT"
        case .speedboat: return "SPEEDBOAT"
        case .horizontalTrafficLight: return "HORIZONTAL TRAFFIC LIGHT"
        case .verticalTrafficLight: return "VERTICAL TRAFFIC LIGHT"
        case .constructionSign: return "CONSTRUCTION SIGN"
        case .policeCarsRevolvingLight: return "POLICE CARS REVOLVING LIGHT"
        case .triangularFlagOnPost: return "TRIANGULAR FLAG ON POST"
        case .door: return "DOOR"
        case .noEntrySign: return "NO ENTRY SIGN"
        case .smokingSymbol: return "SMOKING SYMBOL"
        case .noSmokingSymbol: return "NO SMOKING SYMBOL"
        case .putLitterInItsPlaceSymbol: return "PUT LITTER IN ITS PLACE SYMBOL"
        case .doNotLitterSymbol: return "DO NOT LITTER SYMBOL"
        case .potableWaterSymbol: return "POTABLE WATER SYMBOL"
        case .nonpotableWaterSymbol: return "NON-POTABLE WATER SYMBOL"
        case .bicycle: return "BICYCLE"
        case .noBicycles: return "NO BICYCLES"
        case .womanBiking: return "WOMAN BIKING"
        case .manBiking: return "MAN BIKING"
        case .bicyclist: return "BICYCLIST"
        case .womanMountainBiking: return "WOMAN MOUNTAIN BIKING"
        case .manMountainBiking: return "MAN MOUNTAIN BIKING"
        case .mountainBicyclist: return "MOUNTAIN BICYCLIST"
        case .womanWalking: return "WOMAN WALKING"
        case .womanWalkingFacingRight: return "WOMAN WALKING FACING RIGHT"
        case .manWalking: return "MAN WALKING"
        case .manWalkingFacingRight: return "MAN WALKING FACING RIGHT"
        case .personWalkingFacingRight: return "PERSON WALKING FACING RIGHT"
        case .pedestrian: return "PEDESTRIAN"
        case .noPedestrians: return "NO PEDESTRIANS"
        case .childrenCrossing: return "CHILDREN CROSSING"
        case .mensSymbol: return "MENS SYMBOL"
        case .womensSymbol: return "WOMENS SYMBOL"
        case .restroom: return "RESTROOM"
        case .babySymbol: return "BABY SYMBOL"
        case .toilet: return "TOILET"
        case .waterCloset: return "WATER CLOSET"
        case .shower: return "SHOWER"
        case .bath: return "BATH"
        case .bathtub: return "BATHTUB"
        case .passportControl: return "PASSPORT CONTROL"
        case .customs: return "CUSTOMS"
        case .baggageClaim: return "BAGGAGE CLAIM"
        case .leftLuggage: return "LEFT LUGGAGE"
        case .couchAndLamp: return "COUCH AND LAMP"
        case .sleepingAccommodation: return "SLEEPING ACCOMMODATION"
        case .shoppingBags: return "SHOPPING BAGS"
        case .bellhopBell: return "BELLHOP BELL"
        case .bed: return "BED"
        case .placeOfWorship: return "PLACE OF WORSHIP"
        case .octagonalSign: return "OCTAGONAL SIGN"
        case .shoppingTrolley: return "SHOPPING TROLLEY"
        case .hinduTemple: return "HINDU TEMPLE"
        case .hut: return "HUT"
        case .elevator: return "ELEVATOR"
        case .wireless: return "WIRELESS"
        case .playgroundSlide: return "PLAYGROUND SLIDE"
        case .wheel: return "WHEEL"
        case .ringBuoy: return "RING BUOY"
        case .hammerAndWrench: return "HAMMER AND WRENCH"
        case .shield: return "SHIELD"
        case .oilDrum: return "OIL DRUM"
        case .motorway: return "MOTORWAY"
        case .railwayTrack: return "RAILWAY TRACK"
        case .motorBoat: return "MOTOR BOAT"
        case .smallAirplane: return "SMALL AIRPLANE"
        case .airplaneDeparture: return "AIRPLANE DEPARTURE"
        case .airplaneArriving: return "AIRPLANE ARRIVING"
        case .satellite: return "SATELLITE"
        case .passengerShip: return "PASSENGER SHIP"
        case .scooter: return "SCOOTER"
        case .motorScooter: return "MOTOR SCOOTER"
        case .canoe: return "CANOE"
        case .sled: return "SLED"
        case .flyingSaucer: return "FLYING SAUCER"
        case .skateboard: return "SKATEBOARD"
        case .autoRickshaw: return "AUTO RICKSHAW"
        case .pickupTruck: return "PICKUP TRUCK"
        case .rollerSkate: return "ROLLER SKATE"
        case .largeOrangeCircle: return "LARGE ORANGE CIRCLE"
        case .largeYellowCircle: return "LARGE YELLOW CIRCLE"
        case .largeGreenCircle: return "LARGE GREEN CIRCLE"
        case .largePurpleCircle: return "LARGE PURPLE CIRCLE"
        case .largeBrownCircle: return "LARGE BROWN CIRCLE"
        case .largeRedSquare: return "LARGE RED SQUARE"
        case .largeBlueSquare: return "LARGE BLUE SQUARE"
        case .largeOrangeSquare: return "LARGE ORANGE SQUARE"
        case .largeYellowSquare: return "LARGE YELLOW SQUARE"
        case .largeGreenSquare: return "LARGE GREEN SQUARE"
        case .largePurpleSquare: return "LARGE PURPLE SQUARE"
        case .largeBrownSquare: return "LARGE BROWN SQUARE"
        case .heavyEqualsSign: return "HEAVY EQUALS SIGN"
        case .pinchedFingers: return "PINCHED FINGERS"
        case .whiteHeart: return "WHITE HEART"
        case .brownHeart: return "BROWN HEART"
        case .pinchingHand: return "PINCHING HAND"
        case .zippermouthFace: return "ZIPPER-MOUTH FACE"
        case .moneymouthFace: return "MONEY-MOUTH FACE"
        case .faceWithThermometer: return "FACE WITH THERMOMETER"
        case .nerdFace: return "NERD FACE"
        case .thinkingFace: return "THINKING FACE"
        case .faceWithHeadbandage: return "FACE WITH HEAD-BANDAGE"
        case .robotFace: return "ROBOT FACE"
        case .huggingFace: return "HUGGING FACE"
        case .signOfTheHorns: return "SIGN OF THE HORNS"
        case .callMeHand: return "CALL ME HAND"
        case .raisedBackOfHand: return "RAISED BACK OF HAND"
        case .leftfacingFist: return "LEFT-FACING FIST"
        case .rightfacingFist: return "RIGHT-FACING FIST"
        case .handshake: return "HANDSHAKE"
        case .handWithIndexAndMiddleFingersCrossed: return "HAND WITH INDEX AND MIDDLE FINGERS CROSSED"
        case .iLoveYouHandSign: return "I LOVE YOU HAND SIGN"
        case .faceWithCowboyHat: return "FACE WITH COWBOY HAT"
        case .clownFace: return "CLOWN FACE"
        case .nauseatedFace: return "NAUSEATED FACE"
        case .rollingOnTheFloorLaughing: return "ROLLING ON THE FLOOR LAUGHING"
        case .droolingFace: return "DROOLING FACE"
        case .lyingFace: return "LYING FACE"
        case .womanFacepalming: return "WOMAN FACEPALMING"
        case .manFacepalming: return "MAN FACEPALMING"
        case .facePalm: return "FACE PALM"
        case .sneezingFace: return "SNEEZING FACE"
        case .faceWithOneEyebrowRaised: return "FACE WITH ONE EYEBROW RAISED"
        case .grinningFaceWithStarEyes: return "GRINNING FACE WITH STAR EYES"
        case .grinningFaceWithOneLargeAndOneSmallEye: return "GRINNING FACE WITH ONE LARGE AND ONE SMALL EYE"
        case .faceWithFingerCoveringClosedLips: return "FACE WITH FINGER COVERING CLOSED LIPS"
        case .seriousFaceWithSymbolsCoveringMouth: return "SERIOUS FACE WITH SYMBOLS COVERING MOUTH"
        case .smilingFaceWithSmilingEyesAndHandCoveringMouth: return "SMILING FACE WITH SMILING EYES AND HAND COVERING MOUTH"
        case .faceWithOpenMouthVomiting: return "FACE WITH OPEN MOUTH VOMITING"
        case .shockedFaceWithExplodingHead: return "SHOCKED FACE WITH EXPLODING HEAD"
        case .pregnantWoman: return "PREGNANT WOMAN"
        case .breastfeeding: return "BREAST-FEEDING"
        case .palmsUpTogether: return "PALMS UP TOGETHER"
        case .selfie: return "SELFIE"
        case .prince: return "PRINCE"
        case .womanInTuxedo: return "WOMAN IN TUXEDO"
        case .manInTuxedo: return "MAN IN TUXEDO"
        case .motherChristmas: return "MOTHER CHRISTMAS"
        case .womanShrugging: return "WOMAN SHRUGGING"
        case .manShrugging: return "MAN SHRUGGING"
        case .shrug: return "SHRUG"
        case .womanCartwheeling: return "WOMAN CARTWHEELING"
        case .manCartwheeling: return "MAN CARTWHEELING"
        case .personDoingCartwheel: return "PERSON DOING CARTWHEEL"
        case .womanJuggling: return "WOMAN JUGGLING"
        case .manJuggling: return "MAN JUGGLING"
        case .juggling: return "JUGGLING"
        case .fencer: return "FENCER"
        case .womenWrestling: return "WOMEN WRESTLING"
        case .menWrestling: return "MEN WRESTLING"
        case .wrestlers: return "WRESTLERS"
        case .womanPlayingWaterPolo: return "WOMAN PLAYING WATER POLO"
        case .manPlayingWaterPolo: return "MAN PLAYING WATER POLO"
        case .waterPolo: return "WATER POLO"
        case .womanPlayingHandball: return "WOMAN PLAYING HANDBALL"
        case .manPlayingHandball: return "MAN PLAYING HANDBALL"
        case .handball: return "HANDBALL"
        case .divingMask: return "DIVING MASK"
        case .wiltedFlower: return "WILTED FLOWER"
        case .drumWithDrumsticks: return "DRUM WITH DRUMSTICKS"
        case .clinkingGlasses: return "CLINKING GLASSES"
        case .tumblerGlass: return "TUMBLER GLASS"
        case .spoon: return "SPOON"
        case .goalNet: return "GOAL NET"
        case .firstPlaceMedal: return "FIRST PLACE MEDAL"
        case .secondPlaceMedal: return "SECOND PLACE MEDAL"
        case .thirdPlaceMedal: return "THIRD PLACE MEDAL"
        case .boxingGlove: return "BOXING GLOVE"
        case .martialArtsUniform: return "MARTIAL ARTS UNIFORM"
        case .curlingStone: return "CURLING STONE"
        case .lacrosseStickAndBall: return "LACROSSE STICK AND BALL"
        case .softball: return "SOFTBALL"
        case .flyingDisc: return "FLYING DISC"
        case .croissant: return "CROISSANT"
        case .avocado: return "AVOCADO"
        case .cucumber: return "CUCUMBER"
        case .bacon: return "BACON"
        case .potato: return "POTATO"
        case .carrot: return "CARROT"
        case .baguetteBread: return "BAGUETTE BREAD"
        case .greenSalad: return "GREEN SALAD"
        case .shallowPanOfFood: return "SHALLOW PAN OF FOOD"
        case .stuffedFlatbread: return "STUFFED FLATBREAD"
        case .egg: return "EGG"
        case .glassOfMilk: return "GLASS OF MILK"
        case .peanuts: return "PEANUTS"
        case .kiwifruit: return "KIWIFRUIT"
        case .pancakes: return "PANCAKES"
        case .dumpling: return "DUMPLING"
        case .fortuneCookie: return "FORTUNE COOKIE"
        case .takeoutBox: return "TAKEOUT BOX"
        case .chopsticks: return "CHOPSTICKS"
        case .bowlWithSpoon: return "BOWL WITH SPOON"
        case .cupWithStraw: return "CUP WITH STRAW"
        case .coconut: return "COCONUT"
        case .broccoli: return "BROCCOLI"
        case .pie: return "PIE"
        case .pretzel: return "PRETZEL"
        case .cutOfMeat: return "CUT OF MEAT"
        case .sandwich: return "SANDWICH"
        case .cannedFood: return "CANNED FOOD"
        case .leafyGreen: return "LEAFY GREEN"
        case .mango: return "MANGO"
        case .moonCake: return "MOON CAKE"
        case .bagel: return "BAGEL"
        case .smilingFaceWithSmilingEyesAndThreeHearts: return "SMILING FACE WITH SMILING EYES AND THREE HEARTS"
        case .yawningFace: return "YAWNING FACE"
        case .smilingFaceWithTear: return "SMILING FACE WITH TEAR"
        case .faceWithPartyHornAndPartyHat: return "FACE WITH PARTY HORN AND PARTY HAT"
        case .faceWithUnevenEyesAndWavyMouth: return "FACE WITH UNEVEN EYES AND WAVY MOUTH"
        case .overheatedFace: return "OVERHEATED FACE"
        case .freezingFace: return "FREEZING FACE"
        case .ninja: return "NINJA"
        case .disguisedFace: return "DISGUISED FACE"
        case .faceHoldingBackTears: return "FACE HOLDING BACK TEARS"
        case .faceWithPleadingEyes: return "FACE WITH PLEADING EYES"
        case .sari: return "SARI"
        case .labCoat: return "LAB COAT"
        case .goggles: return "GOGGLES"
        case .hikingBoot: return "HIKING BOOT"
        case .flatShoe: return "FLAT SHOE"
        case .crab: return "CRAB"
        case .lionFace: return "LION FACE"
        case .scorpion: return "SCORPION"
        case .turkey: return "TURKEY"
        case .unicornFace: return "UNICORN FACE"
        case .eagle: return "EAGLE"
        case .duck: return "DUCK"
        case .bat: return "BAT"
        case .shark: return "SHARK"
        case .owl: return "OWL"
        case .foxFace: return "FOX FACE"
        case .butterfly: return "BUTTERFLY"
        case .deer: return "DEER"
        case .gorilla: return "GORILLA"
        case .lizard: return "LIZARD"
        case .rhinoceros: return "RHINOCEROS"
        case .shrimp: return "SHRIMP"
        case .squid: return "SQUID"
        case .giraffeFace: return "GIRAFFE FACE"
        case .zebraFace: return "ZEBRA FACE"
        case .hedgehog: return "HEDGEHOG"
        case .sauropod: return "SAUROPOD"
        case .trex: return "T-REX"
        case .cricket: return "CRICKET"
        case .kangaroo: return "KANGAROO"
        case .llama: return "LLAMA"
        case .peacock: return "PEACOCK"
        case .hippopotamus: return "HIPPOPOTAMUS"
        case .parrot: return "PARROT"
        case .raccoon: return "RACCOON"
        case .lobster: return "LOBSTER"
        case .mosquito: return "MOSQUITO"
        case .microbe: return "MICROBE"
        case .badger: return "BADGER"
        case .swan: return "SWAN"
        case .mammoth: return "MAMMOTH"
        case .dodo: return "DODO"
        case .sloth: return "SLOTH"
        case .otter: return "OTTER"
        case .orangutan: return "ORANGUTAN"
        case .skunk: return "SKUNK"
        case .flamingo: return "FLAMINGO"
        case .oyster: return "OYSTER"
        case .beaver: return "BEAVER"
        case .bison: return "BISON"
        case .seal: return "SEAL"
        case .guideDog: return "GUIDE DOG"
        case .probingCane: return "PROBING CANE"
        case .bone: return "BONE"
        case .leg: return "LEG"
        case .foot: return "FOOT"
        case .tooth: return "TOOTH"
        case .womanSuperhero: return "WOMAN SUPERHERO"
        case .manSuperhero: return "MAN SUPERHERO"
        case .superhero: return "SUPERHERO"
        case .womanSupervillain: return "WOMAN SUPERVILLAIN"
        case .manSupervillain: return "MAN SUPERVILLAIN"
        case .supervillain: return "SUPERVILLAIN"
        case .safetyVest: return "SAFETY VEST"
        case .earWithHearingAid: return "EAR WITH HEARING AID"
        case .motorizedWheelchair: return "MOTORIZED WHEELCHAIR"
        case .manualWheelchair: return "MANUAL WHEELCHAIR"
        case .mechanicalArm: return "MECHANICAL ARM"
        case .mechanicalLeg: return "MECHANICAL LEG"
        case .cheeseWedge: return "CHEESE WEDGE"
        case .cupcake: return "CUPCAKE"
        case .saltShaker: return "SALT SHAKER"
        case .beverageBox: return "BEVERAGE BOX"
        case .garlic: return "GARLIC"
        case .onion: return "ONION"
        case .falafel: return "FALAFEL"
        case .waffle: return "WAFFLE"
        case .butter: return "BUTTER"
        case .mateDrink: return "MATE DRINK"
        case .iceCube: return "ICE CUBE"
        case .bubbleTea: return "BUBBLE TEA"
        case .troll: return "TROLL"
        case .womanStanding: return "WOMAN STANDING"
        case .manStanding: return "MAN STANDING"
        case .standingPerson: return "STANDING PERSON"
        case .womanKneeling: return "WOMAN KNEELING"
        case .womanKneelingFacingRight: return "WOMAN KNEELING FACING RIGHT"
        case .manKneeling: return "MAN KNEELING"
        case .manKneelingFacingRight: return "MAN KNEELING FACING RIGHT"
        case .personKneelingFacingRight: return "PERSON KNEELING FACING RIGHT"
        case .kneelingPerson: return "KNEELING PERSON"
        case .deafWoman: return "DEAF WOMAN"
        case .deafMan: return "DEAF MAN"
        case .deafPerson: return "DEAF PERSON"
        case .faceWithMonocle: return "FACE WITH MONOCLE"
        case .farmer: return "FARMER"
        case .cook: return "COOK"
        case .personFeedingBaby: return "PERSON FEEDING BABY"
        case .mxClaus: return "MX CLAUS"
        case .student: return "STUDENT"
        case .singer: return "SINGER"
        case .artist: return "ARTIST"
        case .teacher: return "TEACHER"
        case .factoryWorker: return "FACTORY WORKER"
        case .technologist: return "TECHNOLOGIST"
        case .officeWorker: return "OFFICE WORKER"
        case .mechanic: return "MECHANIC"
        case .scientist: return "SCIENTIST"
        case .astronaut: return "ASTRONAUT"
        case .firefighter: return "FIREFIGHTER"
        case .peopleHoldingHands: return "PEOPLE HOLDING HANDS"
        case .personWithWhiteCaneFacingRight: return "PERSON WITH WHITE CANE FACING RIGHT"
        case .personWithWhiteCane: return "PERSON WITH WHITE CANE"
        case .personRedHair: return "PERSON: RED HAIR"
        case .personCurlyHair: return "PERSON: CURLY HAIR"
        case .personBald: return "PERSON: BALD"
        case .personWhiteHair: return "PERSON: WHITE HAIR"
        case .personInMotorizedWheelchairFacingRight: return "PERSON IN MOTORIZED WHEELCHAIR FACING RIGHT"
        case .personInMotorizedWheelchair: return "PERSON IN MOTORIZED WHEELCHAIR"
        case .personInManualWheelchairFacingRight: return "PERSON IN MANUAL WHEELCHAIR FACING RIGHT"
        case .personInManualWheelchair: return "PERSON IN MANUAL WHEELCHAIR"
        case .familyAdultAdultChild: return "FAMILY: ADULT, ADULT, CHILD"
        case .familyAdultAdultChildChild: return "FAMILY: ADULT, ADULT, CHILD, CHILD"
        case .familyAdultChildChild: return "FAMILY: ADULT, CHILD, CHILD"
        case .familyAdultChild: return "FAMILY: ADULT, CHILD"
        case .healthWorker: return "HEALTH WORKER"
        case .judge: return "JUDGE"
        case .pilot: return "PILOT"
        case .adult: return "ADULT"
        case .child: return "CHILD"
        case .olderAdult: return "OLDER ADULT"
        case .womanBeard: return "WOMAN: BEARD"
        case .manBeard: return "MAN: BEARD"
        case .beardedPerson: return "BEARDED PERSON"
        case .personWithHeadscarf: return "PERSON WITH HEADSCARF"
        case .womanInSteamyRoom: return "WOMAN IN STEAMY ROOM"
        case .manInSteamyRoom: return "MAN IN STEAMY ROOM"
        case .personInSteamyRoom: return "PERSON IN STEAMY ROOM"
        case .womanClimbing: return "WOMAN CLIMBING"
        case .manClimbing: return "MAN CLIMBING"
        case .personClimbing: return "PERSON CLIMBING"
        case .womanInLotusPosition: return "WOMAN IN LOTUS POSITION"
        case .manInLotusPosition: return "MAN IN LOTUS POSITION"
        case .personInLotusPosition: return "PERSON IN LOTUS POSITION"
        case .womanMage: return "WOMAN MAGE"
        case .manMage: return "MAN MAGE"
        case .mage: return "MAGE"
        case .womanFairy: return "WOMAN FAIRY"
        case .manFairy: return "MAN FAIRY"
        case .fairy: return "FAIRY"
        case .womanVampire: return "WOMAN VAMPIRE"
        case .manVampire: return "MAN VAMPIRE"
        case .vampire: return "VAMPIRE"
        case .mermaid: return "MERMAID"
        case .merman: return "MERMAN"
        case .merperson: return "MERPERSON"
        case .womanElf: return "WOMAN ELF"
        case .manElf: return "MAN ELF"
        case .elf: return "ELF"
        case .womanGenie: return "WOMAN GENIE"
        case .manGenie: return "MAN GENIE"
        case .genie: return "GENIE"
        case .womanZombie: return "WOMAN ZOMBIE"
        case .manZombie: return "MAN ZOMBIE"
        case .zombie: return "ZOMBIE"
        case .brain: return "BRAIN"
        case .orangeHeart: return "ORANGE HEART"
        case .billedCap: return "BILLED CAP"
        case .scarf: return "SCARF"
        case .gloves: return "GLOVES"
        case .coat: return "COAT"
        case .socks: return "SOCKS"
        case .redGiftEnvelope: return "RED GIFT ENVELOPE"
        case .firecracker: return "FIRECRACKER"
        case .jigsawPuzzlePiece: return "JIGSAW PUZZLE PIECE"
        case .testTube: return "TEST TUBE"
        case .petriDish: return "PETRI DISH"
        case .dnaDoubleHelix: return "DNA DOUBLE HELIX"
        case .compass: return "COMPASS"
        case .abacus: return "ABACUS"
        case .fireExtinguisher: return "FIRE EXTINGUISHER"
        case .toolbox: return "TOOLBOX"
        case .brick: return "BRICK"
        case .magnet: return "MAGNET"
        case .luggage: return "LUGGAGE"
        case .lotionBottle: return "LOTION BOTTLE"
        case .spoolOfThread: return "SPOOL OF THREAD"
        case .ballOfYarn: return "BALL OF YARN"
        case .safetyPin: return "SAFETY PIN"
        case .teddyBear: return "TEDDY BEAR"
        case .broom: return "BROOM"
        case .basket: return "BASKET"
        case .rollOfPaper: return "ROLL OF PAPER"
        case .barOfSoap: return "BAR OF SOAP"
        case .sponge: return "SPONGE"
        case .receipt: return "RECEIPT"
        case .nazarAmulet: return "NAZAR AMULET"
        case .balletShoes: return "BALLET SHOES"
        case .onepieceSwimsuit: return "ONE-PIECE SWIMSUIT"
        case .briefs: return "BRIEFS"
        case .shorts: return "SHORTS"
        case .thongSandal: return "THONG SANDAL"
        case .lightBlueHeart: return "LIGHT BLUE HEART"
        case .greyHeart: return "GREY HEART"
        case .pinkHeart: return "PINK HEART"
        case .dropOfBlood: return "DROP OF BLOOD"
        case .adhesiveBandage: return "ADHESIVE BANDAGE"
        case .stethoscope: return "STETHOSCOPE"
        case .xray: return "X-RAY"
        case .crutch: return "CRUTCH"
        case .yoyo: return "YO-YO"
        case .kite: return "KITE"
        case .parachute: return "PARACHUTE"
        case .boomerang: return "BOOMERANG"
        case .magicWand: return "MAGIC WAND"
        case .pinata: return "PINATA"
        case .nestingDolls: return "NESTING DOLLS"
        case .maracas: return "MARACAS"
        case .flute: return "FLUTE"
        case .ringedPlanet: return "RINGED PLANET"
        case .chair: return "CHAIR"
        case .razor: return "RAZOR"
        case .axe: return "AXE"
        case .diyaLamp: return "DIYA LAMP"
        case .banjo: return "BANJO"
        case .militaryHelmet: return "MILITARY HELMET"
        case .accordion: return "ACCORDION"
        case .longDrum: return "LONG DRUM"
        case .coin: return "COIN"
        case .carpentrySaw: return "CARPENTRY SAW"
        case .screwdriver: return "SCREWDRIVER"
        case .ladder: return "LADDER"
        case .hook: return "HOOK"
        case .mirror: return "MIRROR"
        case .window: return "WINDOW"
        case .plunger: return "PLUNGER"
        case .sewingNeedle: return "SEWING NEEDLE"
        case .knot: return "KNOT"
        case .bucket: return "BUCKET"
        case .mouseTrap: return "MOUSE TRAP"
        case .toothbrush: return "TOOTHBRUSH"
        case .headstone: return "HEADSTONE"
        case .placard: return "PLACARD"
        case .rock: return "ROCK"
        case .mirrorBall: return "MIRROR BALL"
        case .identificationCard: return "IDENTIFICATION CARD"
        case .lowBattery: return "LOW BATTERY"
        case .hamsa: return "HAMSA"
        case .foldingHandFan: return "FOLDING HAND FAN"
        case .hairPick: return "HAIR PICK"
        case .khanda: return "KHANDA"
        case .fly: return "FLY"
        case .worm: return "WORM"
        case .beetle: return "BEETLE"
        case .cockroach: return "COCKROACH"
        case .pottedPlant: return "POTTED PLANT"
        case .wood: return "WOOD"
        case .feather: return "FEATHER"
        case .lotus: return "LOTUS"
        case .coral: return "CORAL"
        case .emptyNest: return "EMPTY NEST"
        case .nestWithEggs: return "NEST WITH EGGS"
        case .hyacinth: return "HYACINTH"
        case .jellyfish: return "JELLYFISH"
        case .wing: return "WING"
        case .goose: return "GOOSE"
        case .anatomicalHeart: return "ANATOMICAL HEART"
        case .lungs: return "LUNGS"
        case .peopleHugging: return "PEOPLE HUGGING"
        case .pregnantMan: return "PREGNANT MAN"
        case .pregnantPerson: return "PREGNANT PERSON"
        case .personWithCrown: return "PERSON WITH CROWN"
        case .moose: return "MOOSE"
        case .donkey: return "DONKEY"
        case .blueberries: return "BLUEBERRIES"
        case .bellPepper: return "BELL PEPPER"
        case .olive: return "OLIVE"
        case .flatbread: return "FLATBREAD"
        case .tamale: return "TAMALE"
        case .fondue: return "FONDUE"
        case .teapot: return "TEAPOT"
        case .pouringLiquid: return "POURING LIQUID"
        case .beans: return "BEANS"
        case .jar: return "JAR"
        case .gingerRoot: return "GINGER ROOT"
        case .peaPod: return "PEA POD"
        case .meltingFace: return "MELTING FACE"
        case .salutingFace: return "SALUTING FACE"
        case .faceWithOpenEyesAndHandOverMouth: return "FACE WITH OPEN EYES AND HAND OVER MOUTH"
        case .faceWithPeekingEye: return "FACE WITH PEEKING EYE"
        case .faceWithDiagonalMouth: return "FACE WITH DIAGONAL MOUTH"
        case .dottedLineFace: return "DOTTED LINE FACE"
        case .bitingLip: return "BITING LIP"
        case .bubbles: return "BUBBLES"
        case .shakingFace: return "SHAKING FACE"
        case .handWithIndexFingerAndThumbCrossed: return "HAND WITH INDEX FINGER AND THUMB CROSSED"
        case .rightwardsHand: return "RIGHTWARDS HAND"
        case .leftwardsHand: return "LEFTWARDS HAND"
        case .palmDownHand: return "PALM DOWN HAND"
        case .palmUpHand: return "PALM UP HAND"
        case .indexPointingAtTheViewer: return "INDEX POINTING AT THE VIEWER"
        case .heartHands: return "HEART HANDS"
        case .leftwardsPushingHand: return "LEFTWARDS PUSHING HAND"
        case .rightwardsPushingHand: return "RIGHTWARDS PUSHING HAND"
        case .doubleExclamationMark: return "DOUBLE EXCLAMATION MARK"
        case .exclamationQuestionMark: return "EXCLAMATION QUESTION MARK"
        case .tradeMarkSign: return "TRADE MARK SIGN"
        case .informationSource: return "INFORMATION SOURCE"
        case .leftRightArrow: return "LEFT RIGHT ARROW"
        case .upDownArrow: return "UP DOWN ARROW"
        case .northWestArrow: return "NORTH WEST ARROW"
        case .northEastArrow: return "NORTH EAST ARROW"
        case .southEastArrow: return "SOUTH EAST ARROW"
        case .southWestArrow: return "SOUTH WEST ARROW"
        case .leftwardsArrowWithHook: return "LEFTWARDS ARROW WITH HOOK"
        case .rightwardsArrowWithHook: return "RIGHTWARDS ARROW WITH HOOK"
        case .watch: return "WATCH"
        case .hourglass: return "HOURGLASS"
        case .keyboard: return "KEYBOARD"
        case .ejectButton: return "EJECT BUTTON"
        case .blackRightpointingDoubleTriangle: return "BLACK RIGHT-POINTING DOUBLE TRIANGLE"
        case .blackLeftpointingDoubleTriangle: return "BLACK LEFT-POINTING DOUBLE TRIANGLE"
        case .blackUppointingDoubleTriangle: return "BLACK UP-POINTING DOUBLE TRIANGLE"
        case .blackDownpointingDoubleTriangle: return "BLACK DOWN-POINTING DOUBLE TRIANGLE"
        case .nextTrackButton: return "NEXT TRACK BUTTON"
        case .lastTrackButton: return "LAST TRACK BUTTON"
        case .playOrPauseButton: return "PLAY OR PAUSE BUTTON"
        case .alarmClock: return "ALARM CLOCK"
        case .stopwatch: return "STOPWATCH"
        case .timerClock: return "TIMER CLOCK"
        case .hourglassWithFlowingSand: return "HOURGLASS WITH FLOWING SAND"
        case .pauseButton: return "PAUSE BUTTON"
        case .stopButton: return "STOP BUTTON"
        case .recordButton: return "RECORD BUTTON"
        case .circledLatinCapitalLetterM: return "CIRCLED LATIN CAPITAL LETTER M"
        case .blackSmallSquare: return "BLACK SMALL SQUARE"
        case .whiteSmallSquare: return "WHITE SMALL SQUARE"
        case .blackRightpointingTriangle: return "BLACK RIGHT-POINTING TRIANGLE"
        case .blackLeftpointingTriangle: return "BLACK LEFT-POINTING TRIANGLE"
        case .whiteMediumSquare: return "WHITE MEDIUM SQUARE"
        case .blackMediumSquare: return "BLACK MEDIUM SQUARE"
        case .whiteMediumSmallSquare: return "WHITE MEDIUM SMALL SQUARE"
        case .blackMediumSmallSquare: return "BLACK MEDIUM SMALL SQUARE"
        case .blackSunWithRays: return "BLACK SUN WITH RAYS"
        case .cloud: return "CLOUD"
        case .umbrella: return "UMBRELLA"
        case .snowman: return "SNOWMAN"
        case .comet: return "COMET"
        case .blackTelephone: return "BLACK TELEPHONE"
        case .ballotBoxWithCheck: return "BALLOT BOX WITH CHECK"
        case .umbrellaWithRainDrops: return "UMBRELLA WITH RAIN DROPS"
        case .hotBeverage: return "HOT BEVERAGE"
        case .shamrock: return "SHAMROCK"
        case .whiteUpPointingIndex: return "WHITE UP POINTING INDEX"
        case .skullAndCrossbones: return "SKULL AND CROSSBONES"
        case .radioactive: return "RADIOACTIVE"
        case .biohazard: return "BIOHAZARD"
        case .orthodoxCross: return "ORTHODOX CROSS"
        case .starAndCrescent: return "STAR AND CRESCENT"
        case .peaceSymbol: return "PEACE SYMBOL"
        case .yinYang: return "YIN YANG"
        case .wheelOfDharma: return "WHEEL OF DHARMA"
        case .frowningFace: return "FROWNING FACE"
        case .whiteSmilingFace: return "WHITE SMILING FACE"
        case .femaleSign: return "FEMALE SIGN"
        case .maleSign: return "MALE SIGN"
        case .aries: return "ARIES"
        case .taurus: return "TAURUS"
        case .gemini: return "GEMINI"
        case .cancer: return "CANCER"
        case .leo: return "LEO"
        case .virgo: return "VIRGO"
        case .libra: return "LIBRA"
        case .scorpius: return "SCORPIUS"
        case .sagittarius: return "SAGITTARIUS"
        case .capricorn: return "CAPRICORN"
        case .aquarius: return "AQUARIUS"
        case .pisces: return "PISCES"
        case .chessPawn: return "CHESS PAWN"
        case .blackSpadeSuit: return "BLACK SPADE SUIT"
        case .blackClubSuit: return "BLACK CLUB SUIT"
        case .blackHeartSuit: return "BLACK HEART SUIT"
        case .blackDiamondSuit: return "BLACK DIAMOND SUIT"
        case .hotSprings: return "HOT SPRINGS"
        case .blackUniversalRecyclingSymbol: return "BLACK UNIVERSAL RECYCLING SYMBOL"
        case .infinity: return "INFINITY"
        case .wheelchairSymbol: return "WHEELCHAIR SYMBOL"
        case .hammerAndPick: return "HAMMER AND PICK"
        case .anchor: return "ANCHOR"
        case .crossedSwords: return "CROSSED SWORDS"
        case .medicalSymbol: return "MEDICAL SYMBOL"
        case .balanceScale: return "BALANCE SCALE"
        case .alembic: return "ALEMBIC"
        case .gear: return "GEAR"
        case .atomSymbol: return "ATOM SYMBOL"
        case .fleurdelis: return "FLEUR-DE-LIS"
        case .warningSign: return "WARNING SIGN"
        case .highVoltageSign: return "HIGH VOLTAGE SIGN"
        case .transgenderSymbol: return "TRANSGENDER SYMBOL"
        case .mediumWhiteCircle: return "MEDIUM WHITE CIRCLE"
        case .mediumBlackCircle: return "MEDIUM BLACK CIRCLE"
        case .coffin: return "COFFIN"
        case .funeralUrn: return "FUNERAL URN"
        case .soccerBall: return "SOCCER BALL"
        case .baseball: return "BASEBALL"
        case .snowmanWithoutSnow: return "SNOWMAN WITHOUT SNOW"
        case .sunBehindCloud: return "SUN BEHIND CLOUD"
        case .cloudWithLightningAndRain: return "CLOUD WITH LIGHTNING AND RAIN"
        case .ophiuchus: return "OPHIUCHUS"
        case .pick: return "PICK"
        case .rescueWorkersHelmet: return "RESCUE WORKER’S HELMET"
        case .brokenChain: return "BROKEN CHAIN"
        case .chains: return "CHAINS"
        case .noEntry: return "NO ENTRY"
        case .shintoShrine: return "SHINTO SHRINE"
        case .church: return "CHURCH"
        case .mountain: return "MOUNTAIN"
        case .umbrellaOnGround: return "UMBRELLA ON GROUND"
        case .fountain: return "FOUNTAIN"
        case .flagInHole: return "FLAG IN HOLE"
        case .ferry: return "FERRY"
        case .sailboat: return "SAILBOAT"
        case .skier: return "SKIER"
        case .iceSkate: return "ICE SKATE"
        case .womanBouncingBall: return "WOMAN BOUNCING BALL"
        case .manBouncingBall: return "MAN BOUNCING BALL"
        case .personBouncingBall: return "PERSON BOUNCING BALL"
        case .tent: return "TENT"
        case .fuelPump: return "FUEL PUMP"
        case .blackScissors: return "BLACK SCISSORS"
        case .whiteHeavyCheckMark: return "WHITE HEAVY CHECK MARK"
        case .airplane: return "AIRPLANE"
        case .envelope: return "ENVELOPE"
        case .raisedFist: return "RAISED FIST"
        case .raisedHand: return "RAISED HAND"
        case .victoryHand: return "VICTORY HAND"
        case .writingHand: return "WRITING HAND"
        case .pencil: return "PENCIL"
        case .blackNib: return "BLACK NIB"
        case .heavyCheckMark: return "HEAVY CHECK MARK"
        case .heavyMultiplicationX: return "HEAVY MULTIPLICATION X"
        case .latinCross: return "LATIN CROSS"
        case .starOfDavid: return "STAR OF DAVID"
        case .sparkles: return "SPARKLES"
        case .eightSpokedAsterisk: return "EIGHT SPOKED ASTERISK"
        case .eightPointedBlackStar: return "EIGHT POINTED BLACK STAR"
        case .snowflake: return "SNOWFLAKE"
        case .sparkle: return "SPARKLE"
        case .crossMark: return "CROSS MARK"
        case .negativeSquaredCrossMark: return "NEGATIVE SQUARED CROSS MARK"
        case .blackQuestionMarkOrnament: return "BLACK QUESTION MARK ORNAMENT"
        case .whiteQuestionMarkOrnament: return "WHITE QUESTION MARK ORNAMENT"
        case .whiteExclamationMarkOrnament: return "WHITE EXCLAMATION MARK ORNAMENT"
        case .heavyExclamationMarkSymbol: return "HEAVY EXCLAMATION MARK SYMBOL"
        case .heartExclamation: return "HEART EXCLAMATION"
        case .heartOnFire: return "HEART ON FIRE"
        case .mendingHeart: return "MENDING HEART"
        case .heavyBlackHeart: return "HEAVY BLACK HEART"
        case .heavyPlusSign: return "HEAVY PLUS SIGN"
        case .heavyMinusSign: return "HEAVY MINUS SIGN"
        case .heavyDivisionSign: return "HEAVY DIVISION SIGN"
        case .blackRightwardsArrow: return "BLACK RIGHTWARDS ARROW"
        case .curlyLoop: return "CURLY LOOP"
        case .doubleCurlyLoop: return "DOUBLE CURLY LOOP"
        case .arrowPointingRightwardsThenCurvingUpwards: return "ARROW POINTING RIGHTWARDS THEN CURVING UPWARDS"
        case .arrowPointingRightwardsThenCurvingDownwards: return "ARROW POINTING RIGHTWARDS THEN CURVING DOWNWARDS"
        case .leftwardsBlackArrow: return "LEFTWARDS BLACK ARROW"
        case .upwardsBlackArrow: return "UPWARDS BLACK ARROW"
        case .downwardsBlackArrow: return "DOWNWARDS BLACK ARROW"
        case .blackLargeSquare: return "BLACK LARGE SQUARE"
        case .whiteLargeSquare: return "WHITE LARGE SQUARE"
        case .whiteMediumStar: return "WHITE MEDIUM STAR"
        case .heavyLargeCircle: return "HEAVY LARGE CIRCLE"
        case .wavyDash: return "WAVY DASH"
        case .partAlternationMark: return "PART ALTERNATION MARK"
        case .circledIdeographCongratulation: return "CIRCLED IDEOGRAPH CONGRATULATION"
        case .circledIdeographSecret: return "CIRCLED IDEOGRAPH SECRET"
        }
    }

    public var sortOrder: Int {
        switch self {
        case .hashKey: return 1549
        case .keycap: return 1550
        case .keycap0: return 1551
        case .keycap1: return 1552
        case .keycap2: return 1553
        case .keycap3: return 1554
        case .keycap4: return 1555
        case .keycap5: return 1556
        case .keycap6: return 1557
        case .keycap7: return 1558
        case .keycap8: return 1559
        case .keycap9: return 1560
        case .copyrightSign: return 1546
        case .registeredSign: return 1547
        case .mahjongTileRedDragon: return 1141
        case .playingCardBlackJoker: return 1140
        case .negativeSquaredLatinCapitalLetterA: return 1567
        case .negativeSquaredLatinCapitalLetterB: return 1569
        case .negativeSquaredLatinCapitalLetterO: return 1578
        case .negativeSquaredLatinCapitalLetterP: return 1580
        case .negativeSquaredAb: return 1568
        case .squaredCl: return 1570
        case .squaredCool: return 1571
        case .squaredFree: return 1572
        case .squaredId: return 1574
        case .squaredNew: return 1576
        case .squaredNg: return 1577
        case .squaredOk: return 1579
        case .squaredSos: return 1581
        case .squaredUpWithExclamationMark: return 1582
        case .squaredVs: return 1583
        case .ascensionIslandFlag: return 1643
        case .andorraFlag: return 1644
        case .unitedArabEmiratesFlag: return 1645
        case .afghanistanFlag: return 1646
        case .antiguaBarbudaFlag: return 1647
        case .anguillaFlag: return 1648
        case .albaniaFlag: return 1649
        case .armeniaFlag: return 1650
        case .angolaFlag: return 1651
        case .antarcticaFlag: return 1652
        case .argentinaFlag: return 1653
        case .americanSamoaFlag: return 1654
        case .austriaFlag: return 1655
        case .australiaFlag: return 1656
        case .arubaFlag: return 1657
        case .ålandIslandsFlag: return 1658
        case .azerbaijanFlag: return 1659
        case .bosniaHerzegovinaFlag: return 1660
        case .barbadosFlag: return 1661
        case .bangladeshFlag: return 1662
        case .belgiumFlag: return 1663
        case .burkinaFasoFlag: return 1664
        case .bulgariaFlag: return 1665
        case .bahrainFlag: return 1666
        case .burundiFlag: return 1667
        case .beninFlag: return 1668
        case .stBarthélemyFlag: return 1669
        case .bermudaFlag: return 1670
        case .bruneiFlag: return 1671
        case .boliviaFlag: return 1672
        case .caribbeanNetherlandsFlag: return 1673
        case .brazilFlag: return 1674
        case .bahamasFlag: return 1675
        case .bhutanFlag: return 1676
        case .bouvetIslandFlag: return 1677
        case .botswanaFlag: return 1678
        case .belarusFlag: return 1679
        case .belizeFlag: return 1680
        case .canadaFlag: return 1681
        case .cocosKeelingIslandsFlag: return 1682
        case .congoKinshasaFlag: return 1683
        case .centralAfricanRepublicFlag: return 1684
        case .congoBrazzavilleFlag: return 1685
        case .switzerlandFlag: return 1686
        case .côteDivoireFlag: return 1687
        case .cookIslandsFlag: return 1688
        case .chileFlag: return 1689
        case .cameroonFlag: return 1690
        case .chinaFlag: return 1691
        case .colombiaFlag: return 1692
        case .clippertonIslandFlag: return 1693
        case .costaRicaFlag: return 1694
        case .cubaFlag: return 1695
        case .capeVerdeFlag: return 1696
        case .curaçaoFlag: return 1697
        case .christmasIslandFlag: return 1698
        case .cyprusFlag: return 1699
        case .czechiaFlag: return 1700
        case .germanyFlag: return 1701
        case .diegoGarciaFlag: return 1702
        case .djiboutiFlag: return 1703
        case .denmarkFlag: return 1704
        case .dominicaFlag: return 1705
        case .dominicanRepublicFlag: return 1706
        case .algeriaFlag: return 1707
        case .ceutaMelillaFlag: return 1708
        case .ecuadorFlag: return 1709
        case .estoniaFlag: return 1710
        case .egyptFlag: return 1711
        case .westernSaharaFlag: return 1712
        case .eritreaFlag: return 1713
        case .spainFlag: return 1714
        case .ethiopiaFlag: return 1715
        case .europeanUnionFlag: return 1716
        case .finlandFlag: return 1717
        case .fijiFlag: return 1718
        case .falklandIslandsFlag: return 1719
        case .micronesiaFlag: return 1720
        case .faroeIslandsFlag: return 1721
        case .franceFlag: return 1722
        case .gabonFlag: return 1723
        case .unitedKingdomFlag: return 1724
        case .grenadaFlag: return 1725
        case .georgiaFlag: return 1726
        case .frenchGuianaFlag: return 1727
        case .guernseyFlag: return 1728
        case .ghanaFlag: return 1729
        case .gibraltarFlag: return 1730
        case .greenlandFlag: return 1731
        case .gambiaFlag: return 1732
        case .guineaFlag: return 1733
        case .guadeloupeFlag: return 1734
        case .equatorialGuineaFlag: return 1735
        case .greeceFlag: return 1736
        case .southGeorgiaSouthSandwichIslandsFlag: return 1737
        case .guatemalaFlag: return 1738
        case .guamFlag: return 1739
        case .guineabissauFlag: return 1740
        case .guyanaFlag: return 1741
        case .hongKongSarChinaFlag: return 1742
        case .heardMcdonaldIslandsFlag: return 1743
        case .hondurasFlag: return 1744
        case .croatiaFlag: return 1745
        case .haitiFlag: return 1746
        case .hungaryFlag: return 1747
        case .canaryIslandsFlag: return 1748
        case .indonesiaFlag: return 1749
        case .irelandFlag: return 1750
        case .israelFlag: return 1751
        case .isleOfManFlag: return 1752
        case .indiaFlag: return 1753
        case .britishIndianOceanTerritoryFlag: return 1754
        case .iraqFlag: return 1755
        case .iranFlag: return 1756
        case .icelandFlag: return 1757
        case .italyFlag: return 1758
        case .jerseyFlag: return 1759
        case .jamaicaFlag: return 1760
        case .jordanFlag: return 1761
        case .japanFlag: return 1762
        case .kenyaFlag: return 1763
        case .kyrgyzstanFlag: return 1764
        case .cambodiaFlag: return 1765
        case .kiribatiFlag: return 1766
        case .comorosFlag: return 1767
        case .stKittsNevisFlag: return 1768
        case .northKoreaFlag: return 1769
        case .southKoreaFlag: return 1770
        case .kuwaitFlag: return 1771
        case .caymanIslandsFlag: return 1772
        case .kazakhstanFlag: return 1773
        case .laosFlag: return 1774
        case .lebanonFlag: return 1775
        case .stLuciaFlag: return 1776
        case .liechtensteinFlag: return 1777
        case .sriLankaFlag: return 1778
        case .liberiaFlag: return 1779
        case .lesothoFlag: return 1780
        case .lithuaniaFlag: return 1781
        case .luxembourgFlag: return 1782
        case .latviaFlag: return 1783
        case .libyaFlag: return 1784
        case .moroccoFlag: return 1785
        case .monacoFlag: return 1786
        case .moldovaFlag: return 1787
        case .montenegroFlag: return 1788
        case .stMartinFlag: return 1789
        case .madagascarFlag: return 1790
        case .marshallIslandsFlag: return 1791
        case .northMacedoniaFlag: return 1792
        case .maliFlag: return 1793
        case .myanmarBurmaFlag: return 1794
        case .mongoliaFlag: return 1795
        case .macaoSarChinaFlag: return 1796
        case .northernMarianaIslandsFlag: return 1797
        case .martiniqueFlag: return 1798
        case .mauritaniaFlag: return 1799
        case .montserratFlag: return 1800
        case .maltaFlag: return 1801
        case .mauritiusFlag: return 1802
        case .maldivesFlag: return 1803
        case .malawiFlag: return 1804
        case .mexicoFlag: return 1805
        case .malaysiaFlag: return 1806
        case .mozambiqueFlag: return 1807
        case .namibiaFlag: return 1808
        case .newCaledoniaFlag: return 1809
        case .nigerFlag: return 1810
        case .norfolkIslandFlag: return 1811
        case .nigeriaFlag: return 1812
        case .nicaraguaFlag: return 1813
        case .netherlandsFlag: return 1814
        case .norwayFlag: return 1815
        case .nepalFlag: return 1816
        case .nauruFlag: return 1817
        case .niueFlag: return 1818
        case .newZealandFlag: return 1819
        case .omanFlag: return 1820
        case .panamaFlag: return 1821
        case .peruFlag: return 1822
        case .frenchPolynesiaFlag: return 1823
        case .papuaNewGuineaFlag: return 1824
        case .philippinesFlag: return 1825
        case .pakistanFlag: return 1826
        case .polandFlag: return 1827
        case .stPierreMiquelonFlag: return 1828
        case .pitcairnIslandsFlag: return 1829
        case .puertoRicoFlag: return 1830
        case .palestinianTerritoriesFlag: return 1831
        case .portugalFlag: return 1832
        case .palauFlag: return 1833
        case .paraguayFlag: return 1834
        case .qatarFlag: return 1835
        case .réunionFlag: return 1836
        case .romaniaFlag: return 1837
        case .serbiaFlag: return 1838
        case .russiaFlag: return 1839
        case .rwandaFlag: return 1840
        case .saudiArabiaFlag: return 1841
        case .solomonIslandsFlag: return 1842
        case .seychellesFlag: return 1843
        case .sudanFlag: return 1844
        case .swedenFlag: return 1845
        case .singaporeFlag: return 1846
        case .stHelenaFlag: return 1847
        case .sloveniaFlag: return 1848
        case .svalbardJanMayenFlag: return 1849
        case .slovakiaFlag: return 1850
        case .sierraLeoneFlag: return 1851
        case .sanMarinoFlag: return 1852
        case .senegalFlag: return 1853
        case .somaliaFlag: return 1854
        case .surinameFlag: return 1855
        case .southSudanFlag: return 1856
        case .sãoToméPríncipeFlag: return 1857
        case .elSalvadorFlag: return 1858
        case .sintMaartenFlag: return 1859
        case .syriaFlag: return 1860
        case .eswatiniFlag: return 1861
        case .tristanDaCunhaFlag: return 1862
        case .turksCaicosIslandsFlag: return 1863
        case .chadFlag: return 1864
        case .frenchSouthernTerritoriesFlag: return 1865
        case .togoFlag: return 1866
        case .thailandFlag: return 1867
        case .tajikistanFlag: return 1868
        case .tokelauFlag: return 1869
        case .timorlesteFlag: return 1870
        case .turkmenistanFlag: return 1871
        case .tunisiaFlag: return 1872
        case .tongaFlag: return 1873
        case .türkiyeFlag: return 1874
        case .trinidadTobagoFlag: return 1875
        case .tuvaluFlag: return 1876
        case .taiwanFlag: return 1877
        case .tanzaniaFlag: return 1878
        case .ukraineFlag: return 1879
        case .ugandaFlag: return 1880
        case .usOutlyingIslandsFlag: return 1881
        case .unitedNationsFlag: return 1882
        case .unitedStatesFlag: return 1883
        case .uruguayFlag: return 1884
        case .uzbekistanFlag: return 1885
        case .vaticanCityFlag: return 1886
        case .stVincentGrenadinesFlag: return 1887
        case .venezuelaFlag: return 1888
        case .britishVirginIslandsFlag: return 1889
        case .usVirginIslandsFlag: return 1890
        case .vietnamFlag: return 1891
        case .vanuatuFlag: return 1892
        case .wallisFutunaFlag: return 1893
        case .samoaFlag: return 1894
        case .kosovoFlag: return 1895
        case .yemenFlag: return 1896
        case .mayotteFlag: return 1897
        case .southAfricaFlag: return 1898
        case .zambiaFlag: return 1899
        case .zimbabweFlag: return 1900
        case .squaredKatakanaKoko: return 1584
        case .squaredKatakanaSa: return 1585
        case .squaredCjkUnifiedIdeograph7121: return 1591
        case .squaredCjkUnifiedIdeograph6307: return 1588
        case .squaredCjkUnifiedIdeograph7981: return 1592
        case .squaredCjkUnifiedIdeograph7A7A: return 1596
        case .squaredCjkUnifiedIdeograph5408: return 1595
        case .squaredCjkUnifiedIdeograph6E80: return 1600
        case .squaredCjkUnifiedIdeograph6709: return 1587
        case .squaredCjkUnifiedIdeograph6708: return 1586
        case .squaredCjkUnifiedIdeograph7533: return 1594
        case .squaredCjkUnifiedIdeograph5272: return 1590
        case .squaredCjkUnifiedIdeograph55B6: return 1599
        case .circledIdeographAdvantage: return 1589
        case .circledIdeographAccept: return 1593
        case .cyclone: return 1051
        case .foggy: return 898
        case .closedUmbrella: return 1053
        case .nightWithStars: return 899
        case .sunriseOverMountains: return 901
        case .sunrise: return 902
        case .cityscapeAtDusk: return 903
        case .sunsetOverBuildings: return 904
        case .rainbow: return 1052
        case .bridgeAtNight: return 905
        case .waterWave: return 1064
        case .volcano: return 856
        case .milkyWay: return 1038
        case .earthGlobeEuropeafrica: return 847
        case .earthGlobeAmericas: return 848
        case .earthGlobeAsiaaustralia: return 849
        case .globeWithMeridians: return 850
        case .newMoonSymbol: return 1018
        case .waxingCrescentMoonSymbol: return 1019
        case .firstQuarterMoonSymbol: return 1020
        case .waxingGibbousMoonSymbol: return 1021
        case .fullMoonSymbol: return 1022
        case .waningGibbousMoonSymbol: return 1023
        case .lastQuarterMoonSymbol: return 1024
        case .waningCrescentMoonSymbol: return 1025
        case .crescentMoon: return 1026
        case .newMoonWithFace: return 1027
        case .firstQuarterMoonWithFace: return 1028
        case .lastQuarterMoonWithFace: return 1029
        case .fullMoonWithFace: return 1032
        case .sunWithFace: return 1033
        case .glowingStar: return 1036
        case .shootingStar: return 1037
        case .thermometer: return 1030
        case .sunBehindSmallCloud: return 1042
        case .sunBehindLargeCloud: return 1043
        case .sunBehindRainCloud: return 1044
        case .cloudWithRain: return 1045
        case .cloudWithSnow: return 1046
        case .cloudWithLightning: return 1047
        case .tornado: return 1048
        case .fog: return 1049
        case .windFace: return 1050
        case .hotDog: return 766
        case .taco: return 768
        case .burrito: return 769
        case .chestnut: return 746
        case .seedling: return 696
        case .evergreenTree: return 698
        case .deciduousTree: return 699
        case .palmTree: return 700
        case .cactus: return 701
        case .hotPepper: return 737
        case .tulip: return 694
        case .cherryBlossom: return 685
        case .rose: return 689
        case .hibiscus: return 691
        case .sunflower: return 692
        case .blossom: return 693
        case .earOfMaize: return 736
        case .earOfRice: return 702
        case .herb: return 703
        case .fourLeafClover: return 705
        case .mapleLeaf: return 706
        case .fallenLeaf: return 707
        case .leafFlutteringInWind: return 708
        case .brownMushroom: return 749
        case .mushroom: return 711
        case .tomato: return 729
        case .aubergine: return 733
        case .grapes: return 712
        case .melon: return 713
        case .watermelon: return 714
        case .tangerine: return 715
        case .lime: return 717
        case .lemon: return 716
        case .banana: return 718
        case .pineapple: return 719
        case .redApple: return 721
        case .greenApple: return 722
        case .pear: return 723
        case .peach: return 724
        case .cherries: return 725
        case .strawberry: return 726
        case .hamburger: return 763
        case .sliceOfPizza: return 765
        case .meatOnBone: return 759
        case .poultryLeg: return 760
        case .riceCracker: return 785
        case .riceBall: return 786
        case .cookedRice: return 787
        case .curryAndRice: return 788
        case .steamingBowl: return 789
        case .spaghetti: return 790
        case .bread: return 750
        case .frenchFries: return 764
        case .roastedSweetPotato: return 791
        case .dango: return 797
        case .oden: return 792
        case .sushi: return 793
        case .friedShrimp: return 794
        case .fishCakeWithSwirlDesign: return 795
        case .softIceCream: return 806
        case .shavedIce: return 807
        case .iceCream: return 808
        case .doughnut: return 809
        case .cookie: return 810
        case .chocolateBar: return 815
        case .candy: return 816
        case .lollipop: return 817
        case .custard: return 818
        case .honeyPot: return 819
        case .shortcake: return 812
        case .bentoBox: return 784
        case .potOfFood: return 776
        case .cooking: return 774
        case .forkAndKnife: return 842
        case .teacupWithoutHandle: return 824
        case .sakeBottleAndCup: return 825
        case .wineGlass: return 827
        case .cocktailGlass: return 828
        case .tropicalDrink: return 829
        case .beerMug: return 830
        case .clinkingBeerMugs: return 831
        case .babyBottle: return 820
        case .forkAndKnifeWithPlate: return 841
        case .bottleWithPoppingCork: return 826
        case .popcorn: return 780
        case .ribbon: return 1081
        case .wrappedPresent: return 1082
        case .birthdayCake: return 811
        case .jackolantern: return 1065
        case .christmasTree: return 1066
        case .fatherChristmas: return 371
        case .fireworks: return 1067
        case .fireworkSparkler: return 1068
        case .balloon: return 1071
        case .partyPopper: return 1072
        case .confettiBall: return 1073
        case .tanabataTree: return 1074
        case .crossedFlags: return 1637
        case .pineDecoration: return 1075
        case .japaneseDolls: return 1076
        case .carpStreamer: return 1077
        case .windChime: return 1078
        case .moonViewingCeremony: return 1079
        case .schoolSatchel: return 1175
        case .graduationCap: return 1189
        case .militaryMedal: return 1086
        case .reminderRibbon: return 1083
        case .studioMicrophone: return 1209
        case .levelSlider: return 1210
        case .controlKnobs: return 1211
        case .filmFrames: return 1247
        case .admissionTickets: return 1084
        case .carouselHorse: return 907
        case .ferrisWheel: return 909
        case .rollerCoaster: return 910
        case .fishingPoleAndFish: return 1113
        case .microphone: return 1212
        case .movieCamera: return 1246
        case .cinema: return 1503
        case .headphone: return 1213
        case .artistPalette: return 1145
        case .topHat: return 1188
        case .circusTent: return 912
        case .ticket: return 1085
        case .clapperBoard: return 1249
        case .performingArts: return 1143
        case .videoGame: return 1126
        case .directHit: return 1119
        case .slotMachine: return 1128
        case .billiards: return 1123
        case .gameDie: return 1129
        case .bowling: return 1101
        case .flowerPlayingCards: return 1142
        case .musicalNote: return 1207
        case .multipleMusicalNotes: return 1208
        case .saxophone: return 1215
        case .guitar: return 1217
        case .musicalKeyboard: return 1218
        case .trumpet: return 1219
        case .violin: return 1220
        case .musicalScore: return 1206
        case .runningShirtWithSash: return 1115
        case .tennisRacquetAndBall: return 1099
        case .skiAndSkiBoot: return 1116
        case .basketballAndHoop: return 1095
        case .chequeredFlag: return 1635
        case .snowboarder: return 462
        case .womanRunning: return 443
        case .womanRunningFacingRight: return 445
        case .manRunning: return 442
        case .manRunningFacingRight: return 446
        case .personRunningFacingRight: return 444
        case .runner: return 441
        case .womanSurfing: return 468
        case .manSurfing: return 467
        case .surfer: return 466
        case .sportsMedal: return 1088
        case .trophy: return 1087
        case .horseRacing: return 460
        case .americanFootball: return 1097
        case .rugbyFootball: return 1098
        case .womanSwimming: return 474
        case .manSwimming: return 473
        case .swimmer: return 472
        case .womanLiftingWeights: return 480
        case .manLiftingWeights: return 479
        case .personLiftingWeights: return 478
        case .womanGolfing: return 465
        case .manGolfing: return 464
        case .personGolfing: return 463
        case .motorcycle: return 943
        case .racingCar: return 942
        case .cricketBatAndBall: return 1102
        case .volleyball: return 1096
        case .fieldHockeyStickAndBall: return 1103
        case .iceHockeyStickAndPuck: return 1104
        case .tableTennisPaddleAndBall: return 1106
        case .snowcappedMountain: return 854
        case .camping: return 858
        case .beachWithUmbrella: return 859
        case .buildingConstruction: return 865
        case .houses: return 870
        case .cityscape: return 900
        case .derelictHouse: return 871
        case .classicalBuilding: return 864
        case .desert: return 860
        case .desertIsland: return 861
        case .nationalPark: return 862
        case .stadium: return 863
        case .houseBuilding: return 872
        case .houseWithGarden: return 873
        case .officeBuilding: return 874
        case .japanesePostOffice: return 875
        case .europeanPostOffice: return 876
        case .hospital: return 877
        case .bank: return 878
        case .automatedTellerMachine: return 1412
        case .hotel: return 879
        case .loveHotel: return 880
        case .convenienceStore: return 881
        case .school: return 882
        case .departmentStore: return 883
        case .factory: return 884
        case .izakayaLantern: return 1260
        case .japaneseCastle: return 885
        case .europeanCastle: return 886
        case .rainbowFlag: return 1640
        case .transgenderFlag: return 1641
        case .whiteFlag: return 1639
        case .pirateFlag: return 1642
        case .englandFlag: return 1901
        case .scotlandFlag: return 1902
        case .walesFlag: return 1903
        case .wavingBlackFlag: return 1638
        case .rosette: return 688
        case .label: return 1278
        case .badmintonRacquetAndShuttlecock: return 1107
        case .bowAndArrow: return 1347
        case .amphora: return 846
        case .emojiModifierFitzpatrickType12: return 554
        case .emojiModifierFitzpatrickType3: return 555
        case .emojiModifierFitzpatrickType4: return 556
        case .emojiModifierFitzpatrickType5: return 557
        case .emojiModifierFitzpatrickType6: return 558
        case .rat: return 607
        case .mouse: return 606
        case .ox: return 587
        case .waterBuffalo: return 588
        case .cow: return 589
        case .tiger: return 576
        case .leopard: return 577
        case .rabbit: return 610
        case .blackCat: return 573
        case .cat: return 572
        case .dragon: return 653
        case .crocodile: return 648
        case .whale: return 657
        case .snail: return 668
        case .snake: return 651
        case .horse: return 581
        case .ram: return 594
        case .goat: return 596
        case .sheep: return 595
        case .monkey: return 560
        case .rooster: return 627
        case .chicken: return 626
        case .serviceDog: return 566
        case .dog: return 564
        case .pig: return 591
        case .boar: return 592
        case .elephant: return 601
        case .octopus: return 664
        case .spiralShell: return 665
        case .bug: return 670
        case .ant: return 671
        case .honeybee: return 672
        case .ladyBeetle: return 674
        case .fish: return 660
        case .tropicalFish: return 661
        case .blowfish: return 662
        case .turtle: return 649
        case .hatchingChick: return 628
        case .babyChick: return 629
        case .frontfacingBabyChick: return 630
        case .phoenix: return 646
        case .blackBird: return 644
        case .bird: return 631
        case .penguin: return 632
        case .koala: return 617
        case .poodle: return 567
        case .dromedaryCamel: return 597
        case .bactrianCamel: return 598
        case .dolphin: return 658
        case .mouseFace: return 605
        case .cowFace: return 586
        case .tigerFace: return 575
        case .rabbitFace: return 609
        case .catFace: return 571
        case .dragonFace: return 652
        case .spoutingWhale: return 656
        case .horseFace: return 578
        case .monkeyFace: return 559
        case .dogFace: return 563
        case .pigFace: return 590
        case .frogFace: return 647
        case .hamsterFace: return 608
        case .wolfFace: return 568
        case .polarBear: return 616
        case .bearFace: return 615
        case .pandaFace: return 618
        case .pigNose: return 593
        case .pawPrints: return 624
        case .chipmunk: return 611
        case .eyes: return 225
        case .eyeInSpeechBubble: return 164
        case .eye: return 226
        case .ear: return 217
        case .nose: return 219
        case .mouth: return 228
        case .tongue: return 227
        case .whiteUpPointingBackhandIndex: return 191
        case .whiteDownPointingBackhandIndex: return 193
        case .whiteLeftPointingBackhandIndex: return 189
        case .whiteRightPointingBackhandIndex: return 190
        case .fistedHandSign: return 199
        case .wavingHandSign: return 169
        case .okHandSign: return 180
        case .thumbsUpSign: return 196
        case .thumbsDownSign: return 197
        case .clappingHandsSign: return 202
        case .openHandsSign: return 205
        case .crown: return 1186
        case .womansHat: return 1187
        case .eyeglasses: return 1150
        case .necktie: return 1155
        case .tshirt: return 1156
        case .jeans: return 1157
        case .dress: return 1162
        case .kimono: return 1163
        case .bikini: return 1168
        case .womansClothes: return 1169
        case .purse: return 1171
        case .handbag: return 1172
        case .pouch: return 1173
        case .mansShoe: return 1177
        case .athleticShoe: return 1178
        case .highheeledShoe: return 1181
        case .womansSandal: return 1182
        case .womansBoots: return 1184
        case .footprints: return 553
        case .bustInSilhouette: return 545
        case .bustsInSilhouette: return 546
        case .boy: return 232
        case .girl: return 233
        case .manFarmer: return 301
        case .manCook: return 304
        case .manFeedingBaby: return 368
        case .manStudent: return 292
        case .manSinger: return 322
        case .manArtist: return 325
        case .manTeacher: return 295
        case .manFactoryWorker: return 310
        case .familyManBoyBoy: return 535
        case .familyManBoy: return 534
        case .familyManGirlBoy: return 537
        case .familyManGirlGirl: return 538
        case .familyManGirl: return 536
        case .familyManManBoy: return 524
        case .familyManManBoyBoy: return 527
        case .familyManManGirl: return 525
        case .familyManManGirlBoy: return 526
        case .familyManManGirlGirl: return 528
        case .familyManWomanBoy: return 519
        case .familyManWomanBoyBoy: return 522
        case .familyManWomanGirl: return 520
        case .familyManWomanGirlBoy: return 521
        case .familyManWomanGirlGirl: return 523
        case .manTechnologist: return 319
        case .manOfficeWorker: return 313
        case .manMechanic: return 307
        case .manScientist: return 316
        case .manAstronaut: return 331
        case .manFirefighter: return 334
        case .manWithWhiteCaneFacingRight: return 426
        case .manWithWhiteCane: return 425
        case .manRedHair: return 240
        case .manCurlyHair: return 241
        case .manBald: return 243
        case .manWhiteHair: return 242
        case .manInMotorizedWheelchairFacingRight: return 432
        case .manInMotorizedWheelchair: return 431
        case .manInManualWheelchairFacingRight: return 438
        case .manInManualWheelchair: return 437
        case .manHealthWorker: return 289
        case .manJudge: return 298
        case .manPilot: return 328
        case .coupleWithHeartManMan: return 517
        case .kissManMan: return 513
        case .man: return 236
        case .womanFarmer: return 302
        case .womanCook: return 305
        case .womanFeedingBaby: return 367
        case .womanStudent: return 293
        case .womanSinger: return 323
        case .womanArtist: return 326
        case .womanTeacher: return 296
        case .womanFactoryWorker: return 311
        case .familyWomanBoyBoy: return 540
        case .familyWomanBoy: return 539
        case .familyWomanGirlBoy: return 542
        case .familyWomanGirlGirl: return 543
        case .familyWomanGirl: return 541
        case .familyWomanWomanBoy: return 529
        case .familyWomanWomanBoyBoy: return 532
        case .familyWomanWomanGirl: return 530
        case .familyWomanWomanGirlBoy: return 531
        case .familyWomanWomanGirlGirl: return 533
        case .womanTechnologist: return 320
        case .womanOfficeWorker: return 314
        case .womanMechanic: return 308
        case .womanScientist: return 317
        case .womanAstronaut: return 332
        case .womanFirefighter: return 335
        case .womanWithWhiteCaneFacingRight: return 428
        case .womanWithWhiteCane: return 427
        case .womanRedHair: return 245
        case .womanCurlyHair: return 247
        case .womanBald: return 251
        case .womanWhiteHair: return 249
        case .womanInMotorizedWheelchairFacingRight: return 434
        case .womanInMotorizedWheelchair: return 433
        case .womanInManualWheelchairFacingRight: return 440
        case .womanInManualWheelchair: return 439
        case .womanHealthWorker: return 290
        case .womanJudge: return 299
        case .womanPilot: return 329
        case .coupleWithHeartWomanMan: return 516
        case .coupleWithHeartWomanWoman: return 518
        case .kissWomanMan: return 512
        case .kissWomanWoman: return 514
        case .woman: return 244
        case .family: return 548
        case .manAndWomanHoldingHands: return 509
        case .twoMenHoldingHands: return 510
        case .twoWomenHoldingHands: return 508
        case .womanPoliceOfficer: return 338
        case .manPoliceOfficer: return 337
        case .policeOfficer: return 336
        case .womenWithBunnyEars: return 452
        case .menWithBunnyEars: return 451
        case .womanWithBunnyEars: return 450
        case .womanWithVeil: return 362
        case .manWithVeil: return 361
        case .brideWithVeil: return 360
        case .womanBlondHair: return 253
        case .manBlondHair: return 254
        case .personWithBlondHair: return 235
        case .manWithGuaPiMao: return 355
        case .womanWearingTurban: return 354
        case .manWearingTurban: return 353
        case .manWithTurban: return 352
        case .olderMan: return 256
        case .olderWoman: return 257
        case .baby: return 230
        case .womanConstructionWorker: return 348
        case .manConstructionWorker: return 347
        case .constructionWorker: return 346
        case .princess: return 351
        case .japaneseOgre: return 112
        case .japaneseGoblin: return 113
        case .ghost: return 114
        case .babyAngel: return 370
        case .extraterrestrialAlien: return 115
        case .alienMonster: return 116
        case .imp: return 107
        case .skull: return 108
        case .womanTippingHand: return 272
        case .manTippingHand: return 271
        case .informationDeskPerson: return 270
        case .womanGuard: return 344
        case .manGuard: return 343
        case .guardsman: return 342
        case .dancer: return 447
        case .lipstick: return 1194
        case .nailPolish: return 210
        case .womanGettingMassage: return 404
        case .manGettingMassage: return 403
        case .faceMassage: return 402
        case .womanGettingHaircut: return 407
        case .manGettingHaircut: return 406
        case .haircut: return 405
        case .barberPole: return 911
        case .syringe: return 1371
        case .pill: return 1373
        case .kissMark: return 155
        case .loveLetter: return 130
        case .ring: return 1195
        case .gemStone: return 1196
        case .kiss: return 511
        case .bouquet: return 684
        case .coupleWithHeart: return 515
        case .wedding: return 887
        case .beatingHeart: return 135
        case .brokenHeart: return 140
        case .twoHearts: return 137
        case .sparklingHeart: return 133
        case .growingHeart: return 134
        case .heartWithArrow: return 131
        case .blueHeart: return 148
        case .greenHeart: return 147
        case .yellowHeart: return 146
        case .purpleHeart: return 150
        case .heartWithRibbon: return 132
        case .revolvingHearts: return 136
        case .heartDecoration: return 138
        case .diamondShapeWithADotInside: return 1631
        case .electricLightBulb: return 1258
        case .angerSymbol: return 157
        case .bomb: return 1345
        case .sleepingSymbol: return 168
        case .collisionSymbol: return 158
        case .splashingSweatSymbol: return 160
        case .droplet: return 1063
        case .dashSymbol: return 161
        case .pileOfPoo: return 110
        case .flexedBiceps: return 212
        case .dizzySymbol: return 159
        case .speechBalloon: return 163
        case .thoughtBalloon: return 167
        case .whiteFlower: return 686
        case .hundredPointsSymbol: return 156
        case .moneyBag: return 1279
        case .currencyExchange: return 1526
        case .heavyDollarSign: return 1527
        case .creditCard: return 1286
        case .banknoteWithYenSign: return 1281
        case .banknoteWithDollarSign: return 1282
        case .banknoteWithEuroSign: return 1283
        case .banknoteWithPoundSign: return 1284
        case .moneyWithWings: return 1285
        case .chartWithUpwardsTrendAndYenSign: return 1288
        case .seat: return 977
        case .personalComputer: return 1235
        case .briefcase: return 1309
        case .minidisc: return 1241
        case .floppyDisk: return 1242
        case .opticalDisc: return 1243
        case .dvd: return 1244
        case .fileFolder: return 1310
        case .openFileFolder: return 1311
        case .pageWithCurl: return 1271
        case .pageFacingUp: return 1273
        case .calendar: return 1313
        case .tearoffCalendar: return 1314
        case .cardIndex: return 1317
        case .chartWithUpwardsTrend: return 1318
        case .chartWithDownwardsTrend: return 1319
        case .barChart: return 1320
        case .clipboard: return 1321
        case .pushpin: return 1322
        case .roundPushpin: return 1323
        case .paperclip: return 1324
        case .straightRuler: return 1326
        case .triangularRuler: return 1327
        case .bookmarkTabs: return 1276
        case .ledger: return 1270
        case .notebook: return 1269
        case .notebookWithDecorativeCover: return 1262
        case .closedBook: return 1263
        case .openBook: return 1264
        case .greenBook: return 1265
        case .blueBook: return 1266
        case .orangeBook: return 1267
        case .books: return 1268
        case .nameBadge: return 1532
        case .scroll: return 1272
        case .memo: return 1308
        case .telephoneReceiver: return 1229
        case .pager: return 1230
        case .faxMachine: return 1231
        case .satelliteAntenna: return 1370
        case .publicAddressLoudspeaker: return 1201
        case .cheeringMegaphone: return 1202
        case .outboxTray: return 1293
        case .inboxTray: return 1294
        case .package: return 1295
        case .emailSymbol: return 1290
        case .incomingEnvelope: return 1291
        case .envelopeWithDownwardsArrowAbove: return 1292
        case .closedMailboxWithLoweredFlag: return 1297
        case .closedMailboxWithRaisedFlag: return 1296
        case .openMailboxWithRaisedFlag: return 1298
        case .openMailboxWithLoweredFlag: return 1299
        case .postbox: return 1300
        case .postalHorn: return 1203
        case .newspaper: return 1274
        case .mobilePhone: return 1226
        case .mobilePhoneWithRightwardsArrowAtLeft: return 1227
        case .vibrationMode: return 1508
        case .mobilePhoneOff: return 1509
        case .noMobilePhones: return 1434
        case .antennaWithBars: return 1506
        case .camera: return 1251
        case .cameraWithFlash: return 1252
        case .videoCamera: return 1253
        case .television: return 1250
        case .radio: return 1214
        case .videocassette: return 1254
        case .filmProjector: return 1248
        case .prayerBeads: return 1193
        case .twistedRightwardsArrows: return 1485
        case .clockwiseRightwardsAndLeftwardsOpenCircleArrows: return 1486
        case .clockwiseRightwardsAndLeftwardsOpenCircleArrowsWithCircledOneOverlay: return 1487
        case .clockwiseDownwardsAndUpwardsOpenCircleArrows: return 1452
        case .anticlockwiseDownwardsAndUpwardsOpenCircleArrows: return 1453
        case .lowBrightnessSymbol: return 1504
        case .highBrightnessSymbol: return 1505
        case .speakerWithCancellationStroke: return 1197
        case .speaker: return 1198
        case .speakerWithOneSoundWave: return 1199
        case .speakerWithThreeSoundWaves: return 1200
        case .battery: return 1232
        case .electricPlug: return 1234
        case .leftpointingMagnifyingGlass: return 1255
        case .rightpointingMagnifyingGlass: return 1256
        case .lockWithInkPen: return 1334
        case .closedLockWithKey: return 1335
        case .key: return 1336
        case .lock: return 1332
        case .openLock: return 1333
        case .bell: return 1204
        case .bellWithCancellationStroke: return 1205
        case .bookmark: return 1277
        case .linkSymbol: return 1357
        case .radioButton: return 1632
        case .backWithLeftwardsArrowAbove: return 1454
        case .endWithLeftwardsArrowAbove: return 1455
        case .onWithExclamationMarkWithLeftRightArrowAbove: return 1456
        case .soonWithRightwardsArrowAbove: return 1457
        case .topWithUpwardsArrowAbove: return 1458
        case .noOneUnderEighteenSymbol: return 1435
        case .keycapTen: return 1561
        case .inputSymbolForLatinCapitalLetters: return 1562
        case .inputSymbolForLatinSmallLetters: return 1563
        case .inputSymbolForNumbers: return 1564
        case .inputSymbolForSymbols: return 1565
        case .inputSymbolForLatinLetters: return 1566
        case .fire: return 1062
        case .electricTorch: return 1259
        case .wrench: return 1350
        case .hammer: return 1338
        case .nutAndBolt: return 1352
        case .hocho: return 844
        case .pistol: return 1122
        case .microscope: return 1368
        case .telescope: return 1369
        case .crystalBall: return 1124
        case .sixPointedStarWithMiddleDot: return 1470
        case .japaneseSymbolForBeginner: return 1533
        case .tridentEmblem: return 1531
        case .blackSquareButton: return 1634
        case .whiteSquareButton: return 1633
        case .largeRedCircle: return 1601
        case .largeBlueCircle: return 1605
        case .largeOrangeDiamond: return 1625
        case .largeBlueDiamond: return 1626
        case .smallOrangeDiamond: return 1627
        case .smallBlueDiamond: return 1628
        case .uppointingRedTriangle: return 1629
        case .downpointingRedTriangle: return 1630
        case .uppointingSmallRedTriangle: return 1495
        case .downpointingSmallRedTriangle: return 1497
        case .om: return 1461
        case .dove: return 633
        case .kaaba: return 895
        case .mosque: return 891
        case .synagogue: return 893
        case .menorahWithNineBranches: return 1469
        case .clockFaceOneOclock: return 996
        case .clockFaceTwoOclock: return 998
        case .clockFaceThreeOclock: return 1000
        case .clockFaceFourOclock: return 1002
        case .clockFaceFiveOclock: return 1004
        case .clockFaceSixOclock: return 1006
        case .clockFaceSevenOclock: return 1008
        case .clockFaceEightOclock: return 1010
        case .clockFaceNineOclock: return 1012
        case .clockFaceTenOclock: return 1014
        case .clockFaceElevenOclock: return 1016
        case .clockFaceTwelveOclock: return 994
        case .clockFaceOnethirty: return 997
        case .clockFaceTwothirty: return 999
        case .clockFaceThreethirty: return 1001
        case .clockFaceFourthirty: return 1003
        case .clockFaceFivethirty: return 1005
        case .clockFaceSixthirty: return 1007
        case .clockFaceSeventhirty: return 1009
        case .clockFaceEightthirty: return 1011
        case .clockFaceNinethirty: return 1013
        case .clockFaceTenthirty: return 1015
        case .clockFaceEleventhirty: return 1017
        case .clockFaceTwelvethirty: return 995
        case .candle: return 1257
        case .mantelpieceClock: return 993
        case .hole: return 162
        case .personInSuitLevitating: return 449
        case .womanDetective: return 341
        case .manDetective: return 340
        case .detective: return 339
        case .sunglasses: return 1151
        case .spider: return 677
        case .spiderWeb: return 678
        case .joystick: return 1127
        case .manDancing: return 448
        case .linkedPaperclips: return 1325
        case .pen: return 1305
        case .fountainPen: return 1304
        case .paintbrush: return 1306
        case .crayon: return 1307
        case .handWithFingersSplayed: return 171
        case .reversedHandWithMiddleFingerExtended: return 192
        case .raisedHandWithPartBetweenMiddleAndRingFingers: return 173
        case .blackHeart: return 152
        case .desktopComputer: return 1236
        case .printer: return 1237
        case .computerMouse: return 1239
        case .trackball: return 1240
        case .framedPicture: return 1144
        case .cardIndexDividers: return 1312
        case .cardFileBox: return 1329
        case .fileCabinet: return 1330
        case .wastebasket: return 1331
        case .spiralNotepad: return 1315
        case .spiralCalendar: return 1316
        case .clamp: return 1354
        case .oldKey: return 1337
        case .rolledupNewspaper: return 1275
        case .dagger: return 1343
        case .speakingHead: return 544
        case .leftSpeechBubble: return 165
        case .rightAngerBubble: return 166
        case .ballotBoxWithBallot: return 1301
        case .worldMap: return 851
        case .mountFuji: return 857
        case .tokyoTower: return 888
        case .statueOfLiberty: return 889
        case .silhouetteOfJapan: return 852
        case .moyai: return 1409
        case .grinningFace: return 1
        case .grinningFaceWithSmilingEyes: return 4
        case .faceWithTearsOfJoy: return 8
        case .smilingFaceWithOpenMouth: return 2
        case .smilingFaceWithOpenMouthAndSmilingEyes: return 3
        case .smilingFaceWithOpenMouthAndColdSweat: return 6
        case .smilingFaceWithOpenMouthAndTightlyclosedEyes: return 5
        case .smilingFaceWithHalo: return 14
        case .smilingFaceWithHorns: return 106
        case .winkingFace: return 12
        case .smilingFaceWithSmilingEyes: return 13
        case .faceSavouringDeliciousFood: return 24
        case .relievedFace: return 53
        case .smilingFaceWithHeartshapedEyes: return 16
        case .smilingFaceWithSunglasses: return 73
        case .smirkingFace: return 44
        case .neutralFace: return 39
        case .expressionlessFace: return 40
        case .unamusedFace: return 45
        case .faceWithColdSweat: return 98
        case .pensiveFace: return 54
        case .confusedFace: return 76
        case .confoundedFace: return 95
        case .kissingFace: return 19
        case .faceThrowingAKiss: return 18
        case .kissingFaceWithSmilingEyes: return 22
        case .kissingFaceWithClosedEyes: return 21
        case .faceWithStuckoutTongue: return 25
        case .faceWithStuckoutTongueAndWinkingEye: return 26
        case .faceWithStuckoutTongueAndTightlyclosedEyes: return 28
        case .disappointedFace: return 97
        case .worriedFace: return 78
        case .angryFace: return 104
        case .poutingFace: return 103
        case .cryingFace: return 92
        case .perseveringFace: return 96
        case .faceWithLookOfTriumph: return 102
        case .disappointedButRelievedFace: return 91
        case .frowningFaceWithOpenMouth: return 87
        case .anguishedFace: return 88
        case .fearfulFace: return 89
        case .wearyFace: return 99
        case .sleepyFace: return 55
        case .tiredFace: return 100
        case .grimacingFace: return 47
        case .loudlyCryingFace: return 93
        case .faceExhaling: return 48
        case .faceWithOpenMouth: return 81
        case .hushedFace: return 82
        case .faceWithOpenMouthAndColdSweat: return 90
        case .faceScreamingInFear: return 94
        case .astonishedFace: return 83
        case .flushedFace: return 84
        case .sleepingFace: return 57
        case .faceWithSpiralEyes: return 68
        case .dizzyFace: return 67
        case .faceInClouds: return 43
        case .faceWithoutMouth: return 41
        case .faceWithMedicalMask: return 58
        case .grinningCatFaceWithSmilingEyes: return 119
        case .catFaceWithTearsOfJoy: return 120
        case .smilingCatFaceWithOpenMouth: return 118
        case .smilingCatFaceWithHeartshapedEyes: return 121
        case .catFaceWithWrySmile: return 122
        case .kissingCatFaceWithClosedEyes: return 123
        case .poutingCatFace: return 126
        case .cryingCatFace: return 125
        case .wearyCatFace: return 124
        case .slightlyFrowningFace: return 79
        case .headShakingHorizontally: return 51
        case .headShakingVertically: return 52
        case .slightlySmilingFace: return 9
        case .upsidedownFace: return 10
        case .faceWithRollingEyes: return 46
        case .womanGesturingNo: return 266
        case .manGesturingNo: return 265
        case .faceWithNoGoodGesture: return 264
        case .womanGesturingOk: return 269
        case .manGesturingOk: return 268
        case .faceWithOkGesture: return 267
        case .womanBowing: return 281
        case .manBowing: return 280
        case .personBowingDeeply: return 279
        case .seenoevilMonkey: return 127
        case .hearnoevilMonkey: return 128
        case .speaknoevilMonkey: return 129
        case .womanRaisingHand: return 275
        case .manRaisingHand: return 274
        case .happyPersonRaisingOneHand: return 273
        case .personRaisingBothHandsInCelebration: return 203
        case .womanFrowning: return 260
        case .manFrowning: return 259
        case .personFrowning: return 258
        case .womanPouting: return 263
        case .manPouting: return 262
        case .personWithPoutingFace: return 261
        case .personWithFoldedHands: return 208
        case .rocket: return 983
        case .helicopter: return 978
        case .steamLocomotive: return 913
        case .railwayCar: return 914
        case .highspeedTrain: return 915
        case .highspeedTrainWithBulletNose: return 916
        case .train: return 917
        case .metro: return 918
        case .lightRail: return 919
        case .station: return 920
        case .tram: return 921
        case .tramCar: return 924
        case .bus: return 925
        case .oncomingBus: return 926
        case .trolleybus: return 927
        case .busStop: return 952
        case .minibus: return 928
        case .ambulance: return 929
        case .fireEngine: return 930
        case .policeCar: return 931
        case .oncomingPoliceCar: return 932
        case .taxi: return 933
        case .oncomingTaxi: return 934
        case .automobile: return 935
        case .oncomingAutomobile: return 936
        case .recreationalVehicle: return 937
        case .deliveryTruck: return 939
        case .articulatedLorry: return 940
        case .tractor: return 941
        case .monorail: return 922
        case .mountainRailway: return 923
        case .suspensionRailway: return 979
        case .mountainCableway: return 980
        case .aerialTramway: return 981
        case .ship: return 971
        case .womanRowingBoat: return 471
        case .manRowingBoat: return 470
        case .rowboat: return 469
        case .speedboat: return 967
        case .horizontalTrafficLight: return 959
        case .verticalTrafficLight: return 960
        case .constructionSign: return 962
        case .policeCarsRevolvingLight: return 958
        case .triangularFlagOnPost: return 1636
        case .door: return 1378
        case .noEntrySign: return 1428
        case .smokingSymbol: return 1403
        case .noSmokingSymbol: return 1430
        case .putLitterInItsPlaceSymbol: return 1413
        case .doNotLitterSymbol: return 1431
        case .potableWaterSymbol: return 1414
        case .nonpotableWaterSymbol: return 1432
        case .bicycle: return 948
        case .noBicycles: return 1429
        case .womanBiking: return 483
        case .manBiking: return 482
        case .bicyclist: return 481
        case .womanMountainBiking: return 486
        case .manMountainBiking: return 485
        case .mountainBicyclist: return 484
        case .womanWalking: return 410
        case .womanWalkingFacingRight: return 412
        case .manWalking: return 409
        case .manWalkingFacingRight: return 413
        case .personWalkingFacingRight: return 411
        case .pedestrian: return 408
        case .noPedestrians: return 1433
        case .childrenCrossing: return 1426
        case .mensSymbol: return 1416
        case .womensSymbol: return 1417
        case .restroom: return 1418
        case .babySymbol: return 1419
        case .toilet: return 1385
        case .waterCloset: return 1420
        case .shower: return 1387
        case .bath: return 505
        case .bathtub: return 1388
        case .passportControl: return 1421
        case .customs: return 1422
        case .baggageClaim: return 1423
        case .leftLuggage: return 1424
        case .couchAndLamp: return 1383
        case .sleepingAccommodation: return 506
        case .shoppingBags: return 1174
        case .bellhopBell: return 985
        case .bed: return 1382
        case .placeOfWorship: return 1459
        case .octagonalSign: return 961
        case .shoppingTrolley: return 1402
        case .hinduTemple: return 892
        case .hut: return 869
        case .elevator: return 1379
        case .wireless: return 1507
        case .playgroundSlide: return 908
        case .wheel: return 957
        case .ringBuoy: return 964
        case .hammerAndWrench: return 1342
        case .shield: return 1348
        case .oilDrum: return 955
        case .motorway: return 953
        case .railwayTrack: return 954
        case .motorBoat: return 970
        case .smallAirplane: return 973
        case .airplaneDeparture: return 974
        case .airplaneArriving: return 975
        case .satellite: return 982
        case .passengerShip: return 968
        case .scooter: return 949
        case .motorScooter: return 944
        case .canoe: return 966
        case .sled: return 1117
        case .flyingSaucer: return 984
        case .skateboard: return 950
        case .autoRickshaw: return 947
        case .pickupTruck: return 938
        case .rollerSkate: return 951
        case .largeOrangeCircle: return 1602
        case .largeYellowCircle: return 1603
        case .largeGreenCircle: return 1604
        case .largePurpleCircle: return 1606
        case .largeBrownCircle: return 1607
        case .largeRedSquare: return 1610
        case .largeBlueSquare: return 1614
        case .largeOrangeSquare: return 1611
        case .largeYellowSquare: return 1612
        case .largeGreenSquare: return 1613
        case .largePurpleSquare: return 1615
        case .largeBrownSquare: return 1616
        case .heavyEqualsSign: return 1517
        case .pinchedFingers: return 181
        case .whiteHeart: return 154
        case .brownHeart: return 151
        case .pinchingHand: return 182
        case .zippermouthFace: return 37
        case .moneymouthFace: return 29
        case .faceWithThermometer: return 59
        case .nerdFace: return 74
        case .thinkingFace: return 35
        case .faceWithHeadbandage: return 60
        case .robotFace: return 117
        case .huggingFace: return 30
        case .signOfTheHorns: return 187
        case .callMeHand: return 188
        case .raisedBackOfHand: return 170
        case .leftfacingFist: return 200
        case .rightfacingFist: return 201
        case .handshake: return 207
        case .handWithIndexAndMiddleFingersCrossed: return 184
        case .iLoveYouHandSign: return 186
        case .faceWithCowboyHat: return 70
        case .clownFace: return 111
        case .nauseatedFace: return 61
        case .rollingOnTheFloorLaughing: return 7
        case .droolingFace: return 56
        case .lyingFace: return 49
        case .womanFacepalming: return 284
        case .manFacepalming: return 283
        case .facePalm: return 282
        case .sneezingFace: return 63
        case .faceWithOneEyebrowRaised: return 38
        case .grinningFaceWithStarEyes: return 17
        case .grinningFaceWithOneLargeAndOneSmallEye: return 27
        case .faceWithFingerCoveringClosedLips: return 34
        case .seriousFaceWithSymbolsCoveringMouth: return 105
        case .smilingFaceWithSmilingEyesAndHandCoveringMouth: return 31
        case .faceWithOpenMouthVomiting: return 62
        case .shockedFaceWithExplodingHead: return 69
        case .pregnantWoman: return 363
        case .breastfeeding: return 366
        case .palmsUpTogether: return 206
        case .selfie: return 211
        case .prince: return 350
        case .womanInTuxedo: return 359
        case .manInTuxedo: return 358
        case .motherChristmas: return 372
        case .womanShrugging: return 287
        case .manShrugging: return 286
        case .shrug: return 285
        case .womanCartwheeling: return 489
        case .manCartwheeling: return 488
        case .personDoingCartwheel: return 487
        case .womanJuggling: return 501
        case .manJuggling: return 500
        case .juggling: return 499
        case .fencer: return 459
        case .womenWrestling: return 492
        case .menWrestling: return 491
        case .wrestlers: return 490
        case .womanPlayingWaterPolo: return 495
        case .manPlayingWaterPolo: return 494
        case .waterPolo: return 493
        case .womanPlayingHandball: return 498
        case .manPlayingHandball: return 497
        case .handball: return 496
        case .divingMask: return 1114
        case .wiltedFlower: return 690
        case .drumWithDrumsticks: return 1222
        case .clinkingGlasses: return 832
        case .tumblerGlass: return 833
        case .spoon: return 843
        case .goalNet: return 1110
        case .firstPlaceMedal: return 1089
        case .secondPlaceMedal: return 1090
        case .thirdPlaceMedal: return 1091
        case .boxingGlove: return 1108
        case .martialArtsUniform: return 1109
        case .curlingStone: return 1118
        case .lacrosseStickAndBall: return 1105
        case .softball: return 1094
        case .flyingDisc: return 1100
        case .croissant: return 751
        case .avocado: return 732
        case .cucumber: return 739
        case .bacon: return 762
        case .potato: return 734
        case .carrot: return 735
        case .baguetteBread: return 752
        case .greenSalad: return 779
        case .shallowPanOfFood: return 775
        case .stuffedFlatbread: return 771
        case .egg: return 773
        case .glassOfMilk: return 821
        case .peanuts: return 744
        case .kiwifruit: return 728
        case .pancakes: return 756
        case .dumpling: return 798
        case .fortuneCookie: return 799
        case .takeoutBox: return 800
        case .chopsticks: return 840
        case .bowlWithSpoon: return 778
        case .cupWithStraw: return 835
        case .coconut: return 731
        case .broccoli: return 741
        case .pie: return 814
        case .pretzel: return 754
        case .cutOfMeat: return 761
        case .sandwich: return 767
        case .cannedFood: return 783
        case .leafyGreen: return 740
        case .mango: return 720
        case .moonCake: return 796
        case .bagel: return 755
        case .smilingFaceWithSmilingEyesAndThreeHearts: return 15
        case .yawningFace: return 101
        case .smilingFaceWithTear: return 23
        case .faceWithPartyHornAndPartyHat: return 71
        case .faceWithUnevenEyesAndWavyMouth: return 66
        case .overheatedFace: return 64
        case .freezingFace: return 65
        case .ninja: return 345
        case .disguisedFace: return 72
        case .faceHoldingBackTears: return 86
        case .faceWithPleadingEyes: return 85
        case .sari: return 1164
        case .labCoat: return 1153
        case .goggles: return 1152
        case .hikingBoot: return 1179
        case .flatShoe: return 1180
        case .crab: return 801
        case .lionFace: return 574
        case .scorpion: return 679
        case .turkey: return 625
        case .unicornFace: return 582
        case .eagle: return 634
        case .duck: return 635
        case .bat: return 614
        case .shark: return 663
        case .owl: return 637
        case .foxFace: return 569
        case .butterfly: return 669
        case .deer: return 584
        case .gorilla: return 561
        case .lizard: return 650
        case .rhinoceros: return 603
        case .shrimp: return 803
        case .squid: return 804
        case .giraffeFace: return 600
        case .zebraFace: return 583
        case .hedgehog: return 613
        case .sauropod: return 654
        case .trex: return 655
        case .cricket: return 675
        case .kangaroo: return 622
        case .llama: return 599
        case .peacock: return 641
        case .hippopotamus: return 604
        case .parrot: return 642
        case .raccoon: return 570
        case .lobster: return 802
        case .mosquito: return 680
        case .microbe: return 683
        case .badger: return 623
        case .swan: return 636
        case .mammoth: return 602
        case .dodo: return 638
        case .sloth: return 619
        case .otter: return 620
        case .orangutan: return 562
        case .skunk: return 621
        case .flamingo: return 640
        case .oyster: return 805
        case .beaver: return 612
        case .bison: return 585
        case .seal: return 659
        case .guideDog: return 565
        case .probingCane: return 1356
        case .bone: return 224
        case .leg: return 215
        case .foot: return 216
        case .tooth: return 223
        case .womanSuperhero: return 376
        case .manSuperhero: return 375
        case .superhero: return 374
        case .womanSupervillain: return 379
        case .manSupervillain: return 378
        case .supervillain: return 377
        case .safetyVest: return 1154
        case .earWithHearingAid: return 218
        case .motorizedWheelchair: return 946
        case .manualWheelchair: return 945
        case .mechanicalArm: return 213
        case .mechanicalLeg: return 214
        case .cheeseWedge: return 758
        case .cupcake: return 813
        case .saltShaker: return 782
        case .beverageBox: return 837
        case .garlic: return 742
        case .onion: return 743
        case .falafel: return 772
        case .waffle: return 757
        case .butter: return 781
        case .mateDrink: return 838
        case .iceCube: return 839
        case .bubbleTea: return 836
        case .troll: return 401
        case .womanStanding: return 416
        case .manStanding: return 415
        case .standingPerson: return 414
        case .womanKneeling: return 419
        case .womanKneelingFacingRight: return 421
        case .manKneeling: return 418
        case .manKneelingFacingRight: return 422
        case .personKneelingFacingRight: return 420
        case .kneelingPerson: return 417
        case .deafWoman: return 278
        case .deafMan: return 277
        case .deafPerson: return 276
        case .faceWithMonocle: return 75
        case .farmer: return 300
        case .cook: return 303
        case .personFeedingBaby: return 369
        case .mxClaus: return 373
        case .student: return 291
        case .singer: return 321
        case .artist: return 324
        case .teacher: return 294
        case .factoryWorker: return 309
        case .technologist: return 318
        case .officeWorker: return 312
        case .mechanic: return 306
        case .scientist: return 315
        case .astronaut: return 330
        case .firefighter: return 333
        case .peopleHoldingHands: return 507
        case .personWithWhiteCaneFacingRight: return 424
        case .personWithWhiteCane: return 423
        case .personRedHair: return 246
        case .personCurlyHair: return 248
        case .personBald: return 252
        case .personWhiteHair: return 250
        case .personInMotorizedWheelchairFacingRight: return 430
        case .personInMotorizedWheelchair: return 429
        case .personInManualWheelchairFacingRight: return 436
        case .personInManualWheelchair: return 435
        case .familyAdultAdultChild: return 549
        case .familyAdultAdultChildChild: return 550
        case .familyAdultChildChild: return 552
        case .familyAdultChild: return 551
        case .healthWorker: return 288
        case .judge: return 297
        case .pilot: return 327
        case .adult: return 234
        case .child: return 231
        case .olderAdult: return 255
        case .womanBeard: return 239
        case .manBeard: return 238
        case .beardedPerson: return 237
        case .personWithHeadscarf: return 356
        case .womanInSteamyRoom: return 455
        case .manInSteamyRoom: return 454
        case .personInSteamyRoom: return 453
        case .womanClimbing: return 458
        case .manClimbing: return 457
        case .personClimbing: return 456
        case .womanInLotusPosition: return 504
        case .manInLotusPosition: return 503
        case .personInLotusPosition: return 502
        case .womanMage: return 382
        case .manMage: return 381
        case .mage: return 380
        case .womanFairy: return 385
        case .manFairy: return 384
        case .fairy: return 383
        case .womanVampire: return 388
        case .manVampire: return 387
        case .vampire: return 386
        case .mermaid: return 391
        case .merman: return 390
        case .merperson: return 389
        case .womanElf: return 394
        case .manElf: return 393
        case .elf: return 392
        case .womanGenie: return 397
        case .manGenie: return 396
        case .genie: return 395
        case .womanZombie: return 400
        case .manZombie: return 399
        case .zombie: return 398
        case .brain: return 220
        case .orangeHeart: return 145
        case .billedCap: return 1190
        case .scarf: return 1158
        case .gloves: return 1159
        case .coat: return 1160
        case .socks: return 1161
        case .redGiftEnvelope: return 1080
        case .firecracker: return 1069
        case .jigsawPuzzlePiece: return 1130
        case .testTube: return 1365
        case .petriDish: return 1366
        case .dnaDoubleHelix: return 1367
        case .compass: return 853
        case .abacus: return 1245
        case .fireExtinguisher: return 1401
        case .toolbox: return 1361
        case .brick: return 866
        case .magnet: return 1362
        case .luggage: return 986
        case .lotionBottle: return 1391
        case .spoolOfThread: return 1146
        case .ballOfYarn: return 1148
        case .safetyPin: return 1392
        case .teddyBear: return 1131
        case .broom: return 1393
        case .basket: return 1394
        case .rollOfPaper: return 1395
        case .barOfSoap: return 1397
        case .sponge: return 1400
        case .receipt: return 1287
        case .nazarAmulet: return 1407
        case .balletShoes: return 1183
        case .onepieceSwimsuit: return 1165
        case .briefs: return 1166
        case .shorts: return 1167
        case .thongSandal: return 1176
        case .lightBlueHeart: return 149
        case .greyHeart: return 153
        case .pinkHeart: return 144
        case .dropOfBlood: return 1372
        case .adhesiveBandage: return 1374
        case .stethoscope: return 1376
        case .xray: return 1377
        case .crutch: return 1375
        case .yoyo: return 1120
        case .kite: return 1121
        case .parachute: return 976
        case .boomerang: return 1346
        case .magicWand: return 1125
        case .pinata: return 1132
        case .nestingDolls: return 1134
        case .maracas: return 1224
        case .flute: return 1225
        case .ringedPlanet: return 1034
        case .chair: return 1384
        case .razor: return 1390
        case .axe: return 1339
        case .diyaLamp: return 1261
        case .banjo: return 1221
        case .militaryHelmet: return 1191
        case .accordion: return 1216
        case .longDrum: return 1223
        case .coin: return 1280
        case .carpentrySaw: return 1349
        case .screwdriver: return 1351
        case .ladder: return 1363
        case .hook: return 1360
        case .mirror: return 1380
        case .window: return 1381
        case .plunger: return 1386
        case .sewingNeedle: return 1147
        case .knot: return 1149
        case .bucket: return 1396
        case .mouseTrap: return 1389
        case .toothbrush: return 1399
        case .headstone: return 1405
        case .placard: return 1410
        case .rock: return 867
        case .mirrorBall: return 1133
        case .identificationCard: return 1411
        case .lowBattery: return 1233
        case .hamsa: return 1408
        case .foldingHandFan: return 1170
        case .hairPick: return 1185
        case .khanda: return 1471
        case .fly: return 681
        case .worm: return 682
        case .beetle: return 673
        case .cockroach: return 676
        case .pottedPlant: return 697
        case .wood: return 868
        case .feather: return 639
        case .lotus: return 687
        case .coral: return 666
        case .emptyNest: return 709
        case .nestWithEggs: return 710
        case .hyacinth: return 695
        case .jellyfish: return 667
        case .wing: return 643
        case .goose: return 645
        case .anatomicalHeart: return 221
        case .lungs: return 222
        case .peopleHugging: return 547
        case .pregnantMan: return 364
        case .pregnantPerson: return 365
        case .personWithCrown: return 349
        case .moose: return 579
        case .donkey: return 580
        case .blueberries: return 727
        case .bellPepper: return 738
        case .olive: return 730
        case .flatbread: return 753
        case .tamale: return 770
        case .fondue: return 777
        case .teapot: return 823
        case .pouringLiquid: return 834
        case .beans: return 745
        case .jar: return 845
        case .gingerRoot: return 747
        case .peaPod: return 748
        case .meltingFace: return 11
        case .salutingFace: return 36
        case .faceWithOpenEyesAndHandOverMouth: return 32
        case .faceWithPeekingEye: return 33
        case .faceWithDiagonalMouth: return 77
        case .dottedLineFace: return 42
        case .bitingLip: return 229
        case .bubbles: return 1398
        case .shakingFace: return 50
        case .handWithIndexFingerAndThumbCrossed: return 185
        case .rightwardsHand: return 174
        case .leftwardsHand: return 175
        case .palmDownHand: return 176
        case .palmUpHand: return 177
        case .indexPointingAtTheViewer: return 195
        case .heartHands: return 204
        case .leftwardsPushingHand: return 178
        case .rightwardsPushingHand: return 179
        case .doubleExclamationMark: return 1519
        case .exclamationQuestionMark: return 1520
        case .tradeMarkSign: return 1548
        case .informationSource: return 1573
        case .leftRightArrow: return 1447
        case .upDownArrow: return 1446
        case .northWestArrow: return 1445
        case .northEastArrow: return 1439
        case .southEastArrow: return 1441
        case .southWestArrow: return 1443
        case .leftwardsArrowWithHook: return 1448
        case .rightwardsArrowWithHook: return 1449
        case .watch: return 989
        case .hourglass: return 987
        case .keyboard: return 1238
        case .ejectButton: return 1502
        case .blackRightpointingDoubleTriangle: return 1489
        case .blackLeftpointingDoubleTriangle: return 1493
        case .blackUppointingDoubleTriangle: return 1496
        case .blackDownpointingDoubleTriangle: return 1498
        case .nextTrackButton: return 1490
        case .lastTrackButton: return 1494
        case .playOrPauseButton: return 1491
        case .alarmClock: return 990
        case .stopwatch: return 991
        case .timerClock: return 992
        case .hourglassWithFlowingSand: return 988
        case .pauseButton: return 1499
        case .stopButton: return 1500
        case .recordButton: return 1501
        case .circledLatinCapitalLetterM: return 1575
        case .blackSmallSquare: return 1623
        case .whiteSmallSquare: return 1624
        case .blackRightpointingTriangle: return 1488
        case .blackLeftpointingTriangle: return 1492
        case .whiteMediumSquare: return 1620
        case .blackMediumSquare: return 1619
        case .whiteMediumSmallSquare: return 1622
        case .blackMediumSmallSquare: return 1621
        case .blackSunWithRays: return 1031
        case .cloud: return 1039
        case .umbrella: return 1054
        case .snowman: return 1059
        case .comet: return 1061
        case .blackTelephone: return 1228
        case .ballotBoxWithCheck: return 1536
        case .umbrellaWithRainDrops: return 1055
        case .hotBeverage: return 822
        case .shamrock: return 704
        case .whiteUpPointingIndex: return 194
        case .skullAndCrossbones: return 109
        case .radioactive: return 1436
        case .biohazard: return 1437
        case .orthodoxCross: return 1466
        case .starAndCrescent: return 1467
        case .peaceSymbol: return 1468
        case .yinYang: return 1464
        case .wheelOfDharma: return 1463
        case .frowningFace: return 80
        case .whiteSmilingFace: return 20
        case .femaleSign: return 1510
        case .maleSign: return 1511
        case .aries: return 1472
        case .taurus: return 1473
        case .gemini: return 1474
        case .cancer: return 1475
        case .leo: return 1476
        case .virgo: return 1477
        case .libra: return 1478
        case .scorpius: return 1479
        case .sagittarius: return 1480
        case .capricorn: return 1481
        case .aquarius: return 1482
        case .pisces: return 1483
        case .chessPawn: return 1139
        case .blackSpadeSuit: return 1135
        case .blackClubSuit: return 1138
        case .blackHeartSuit: return 1136
        case .blackDiamondSuit: return 1137
        case .hotSprings: return 906
        case .blackUniversalRecyclingSymbol: return 1529
        case .infinity: return 1518
        case .wheelchairSymbol: return 1415
        case .hammerAndPick: return 1341
        case .anchor: return 963
        case .crossedSwords: return 1344
        case .medicalSymbol: return 1528
        case .balanceScale: return 1355
        case .alembic: return 1364
        case .gear: return 1353
        case .atomSymbol: return 1460
        case .fleurdelis: return 1530
        case .warningSign: return 1425
        case .highVoltageSign: return 1057
        case .transgenderSymbol: return 1512
        case .mediumWhiteCircle: return 1609
        case .mediumBlackCircle: return 1608
        case .coffin: return 1404
        case .funeralUrn: return 1406
        case .soccerBall: return 1092
        case .baseball: return 1093
        case .snowmanWithoutSnow: return 1060
        case .sunBehindCloud: return 1040
        case .cloudWithLightningAndRain: return 1041
        case .ophiuchus: return 1484
        case .pick: return 1340
        case .rescueWorkersHelmet: return 1192
        case .brokenChain: return 1358
        case .chains: return 1359
        case .noEntry: return 1427
        case .shintoShrine: return 894
        case .church: return 890
        case .mountain: return 855
        case .umbrellaOnGround: return 1056
        case .fountain: return 896
        case .flagInHole: return 1111
        case .ferry: return 969
        case .sailboat: return 965
        case .skier: return 461
        case .iceSkate: return 1112
        case .womanBouncingBall: return 477
        case .manBouncingBall: return 476
        case .personBouncingBall: return 475
        case .tent: return 897
        case .fuelPump: return 956
        case .blackScissors: return 1328
        case .whiteHeavyCheckMark: return 1535
        case .airplane: return 972
        case .envelope: return 1289
        case .raisedFist: return 198
        case .raisedHand: return 172
        case .victoryHand: return 183
        case .writingHand: return 209
        case .pencil: return 1302
        case .blackNib: return 1303
        case .heavyCheckMark: return 1537
        case .heavyMultiplicationX: return 1513
        case .latinCross: return 1465
        case .starOfDavid: return 1462
        case .sparkles: return 1070
        case .eightSpokedAsterisk: return 1543
        case .eightPointedBlackStar: return 1544
        case .snowflake: return 1058
        case .sparkle: return 1545
        case .crossMark: return 1538
        case .negativeSquaredCrossMark: return 1539
        case .blackQuestionMarkOrnament: return 1521
        case .whiteQuestionMarkOrnament: return 1522
        case .whiteExclamationMarkOrnament: return 1523
        case .heavyExclamationMarkSymbol: return 1524
        case .heartExclamation: return 139
        case .heartOnFire: return 141
        case .mendingHeart: return 142
        case .heavyBlackHeart: return 143
        case .heavyPlusSign: return 1514
        case .heavyMinusSign: return 1515
        case .heavyDivisionSign: return 1516
        case .blackRightwardsArrow: return 1440
        case .curlyLoop: return 1540
        case .doubleCurlyLoop: return 1541
        case .arrowPointingRightwardsThenCurvingUpwards: return 1450
        case .arrowPointingRightwardsThenCurvingDownwards: return 1451
        case .leftwardsBlackArrow: return 1444
        case .upwardsBlackArrow: return 1438
        case .downwardsBlackArrow: return 1442
        case .blackLargeSquare: return 1617
        case .whiteLargeSquare: return 1618
        case .whiteMediumStar: return 1035
        case .heavyLargeCircle: return 1534
        case .wavyDash: return 1525
        case .partAlternationMark: return 1542
        case .circledIdeographCongratulation: return 1597
        case .circledIdeographSecret: return 1598
        }
    }
}

extension Emoji {
    public enum SkinTone: String, CaseIterable, Equatable {
        case light = "1F3FB"
        case mediumLight = "1F3FC"
        case medium = "1F3FD"
        case mediumDark = "1F3FE"
        case dark = "1F3FF"
    }

    public static var allVariants: [Emoji:[[SkinTone]:String]] = {
        return [
			.fatherChristmas:[
				[.light]: "🎅🏻", 
				[.mediumLight]: "🎅🏼", 
				[.medium]: "🎅🏽", 
				[.mediumDark]: "🎅🏾", 
				[.dark]: "🎅🏿"
			],
			.snowboarder:[
				[.light]: "🏂🏻", 
				[.mediumLight]: "🏂🏼", 
				[.medium]: "🏂🏽", 
				[.mediumDark]: "🏂🏾", 
				[.dark]: "🏂🏿"
			],
			.womanRunning:[
				[.light]: "🏃🏻‍♀️", 
				[.mediumLight]: "🏃🏼‍♀️", 
				[.medium]: "🏃🏽‍♀️", 
				[.mediumDark]: "🏃🏾‍♀️", 
				[.dark]: "🏃🏿‍♀️"
			],
			.womanRunningFacingRight:[
				[.light]: "🏃🏻‍♀️‍➡️", 
				[.mediumLight]: "🏃🏼‍♀️‍➡️", 
				[.medium]: "🏃🏽‍♀️‍➡️", 
				[.mediumDark]: "🏃🏾‍♀️‍➡️", 
				[.dark]: "🏃🏿‍♀️‍➡️"
			],
			.manRunning:[
				[.light]: "🏃🏻‍♂️", 
				[.mediumLight]: "🏃🏼‍♂️", 
				[.medium]: "🏃🏽‍♂️", 
				[.mediumDark]: "🏃🏾‍♂️", 
				[.dark]: "🏃🏿‍♂️"
			],
			.manRunningFacingRight:[
				[.light]: "🏃🏻‍♂️‍➡️", 
				[.mediumLight]: "🏃🏼‍♂️‍➡️", 
				[.medium]: "🏃🏽‍♂️‍➡️", 
				[.mediumDark]: "🏃🏾‍♂️‍➡️", 
				[.dark]: "🏃🏿‍♂️‍➡️"
			],
			.personRunningFacingRight:[
				[.light]: "🏃🏻‍➡️", 
				[.mediumLight]: "🏃🏼‍➡️", 
				[.medium]: "🏃🏽‍➡️", 
				[.mediumDark]: "🏃🏾‍➡️", 
				[.dark]: "🏃🏿‍➡️"
			],
			.runner:[
				[.light]: "🏃🏻", 
				[.mediumLight]: "🏃🏼", 
				[.medium]: "🏃🏽", 
				[.mediumDark]: "🏃🏾", 
				[.dark]: "🏃🏿"
			],
			.womanSurfing:[
				[.light]: "🏄🏻‍♀️", 
				[.mediumLight]: "🏄🏼‍♀️", 
				[.medium]: "🏄🏽‍♀️", 
				[.mediumDark]: "🏄🏾‍♀️", 
				[.dark]: "🏄🏿‍♀️"
			],
			.manSurfing:[
				[.light]: "🏄🏻‍♂️", 
				[.mediumLight]: "🏄🏼‍♂️", 
				[.medium]: "🏄🏽‍♂️", 
				[.mediumDark]: "🏄🏾‍♂️", 
				[.dark]: "🏄🏿‍♂️"
			],
			.surfer:[
				[.light]: "🏄🏻", 
				[.mediumLight]: "🏄🏼", 
				[.medium]: "🏄🏽", 
				[.mediumDark]: "🏄🏾", 
				[.dark]: "🏄🏿"
			],
			.horseRacing:[
				[.light]: "🏇🏻", 
				[.mediumLight]: "🏇🏼", 
				[.medium]: "🏇🏽", 
				[.mediumDark]: "🏇🏾", 
				[.dark]: "🏇🏿"
			],
			.womanSwimming:[
				[.light]: "🏊🏻‍♀️", 
				[.mediumLight]: "🏊🏼‍♀️", 
				[.medium]: "🏊🏽‍♀️", 
				[.mediumDark]: "🏊🏾‍♀️", 
				[.dark]: "🏊🏿‍♀️"
			],
			.manSwimming:[
				[.light]: "🏊🏻‍♂️", 
				[.mediumLight]: "🏊🏼‍♂️", 
				[.medium]: "🏊🏽‍♂️", 
				[.mediumDark]: "🏊🏾‍♂️", 
				[.dark]: "🏊🏿‍♂️"
			],
			.swimmer:[
				[.light]: "🏊🏻", 
				[.mediumLight]: "🏊🏼", 
				[.medium]: "🏊🏽", 
				[.mediumDark]: "🏊🏾", 
				[.dark]: "🏊🏿"
			],
			.womanLiftingWeights:[
				[.light]: "🏋🏻‍♀️", 
				[.mediumLight]: "🏋🏼‍♀️", 
				[.medium]: "🏋🏽‍♀️", 
				[.mediumDark]: "🏋🏾‍♀️", 
				[.dark]: "🏋🏿‍♀️"
			],
			.manLiftingWeights:[
				[.light]: "🏋🏻‍♂️", 
				[.mediumLight]: "🏋🏼‍♂️", 
				[.medium]: "🏋🏽‍♂️", 
				[.mediumDark]: "🏋🏾‍♂️", 
				[.dark]: "🏋🏿‍♂️"
			],
			.personLiftingWeights:[
				[.light]: "🏋🏻", 
				[.mediumLight]: "🏋🏼", 
				[.medium]: "🏋🏽", 
				[.mediumDark]: "🏋🏾", 
				[.dark]: "🏋🏿"
			],
			.womanGolfing:[
				[.light]: "🏌🏻‍♀️", 
				[.mediumLight]: "🏌🏼‍♀️", 
				[.medium]: "🏌🏽‍♀️", 
				[.mediumDark]: "🏌🏾‍♀️", 
				[.dark]: "🏌🏿‍♀️"
			],
			.manGolfing:[
				[.light]: "🏌🏻‍♂️", 
				[.mediumLight]: "🏌🏼‍♂️", 
				[.medium]: "🏌🏽‍♂️", 
				[.mediumDark]: "🏌🏾‍♂️", 
				[.dark]: "🏌🏿‍♂️"
			],
			.personGolfing:[
				[.light]: "🏌🏻", 
				[.mediumLight]: "🏌🏼", 
				[.medium]: "🏌🏽", 
				[.mediumDark]: "🏌🏾", 
				[.dark]: "🏌🏿"
			],
			.ear:[
				[.light]: "👂🏻", 
				[.mediumLight]: "👂🏼", 
				[.medium]: "👂🏽", 
				[.mediumDark]: "👂🏾", 
				[.dark]: "👂🏿"
			],
			.nose:[
				[.light]: "👃🏻", 
				[.mediumLight]: "👃🏼", 
				[.medium]: "👃🏽", 
				[.mediumDark]: "👃🏾", 
				[.dark]: "👃🏿"
			],
			.whiteUpPointingBackhandIndex:[
				[.light]: "👆🏻", 
				[.mediumLight]: "👆🏼", 
				[.medium]: "👆🏽", 
				[.mediumDark]: "👆🏾", 
				[.dark]: "👆🏿"
			],
			.whiteDownPointingBackhandIndex:[
				[.light]: "👇🏻", 
				[.mediumLight]: "👇🏼", 
				[.medium]: "👇🏽", 
				[.mediumDark]: "👇🏾", 
				[.dark]: "👇🏿"
			],
			.whiteLeftPointingBackhandIndex:[
				[.light]: "👈🏻", 
				[.mediumLight]: "👈🏼", 
				[.medium]: "👈🏽", 
				[.mediumDark]: "👈🏾", 
				[.dark]: "👈🏿"
			],
			.whiteRightPointingBackhandIndex:[
				[.light]: "👉🏻", 
				[.mediumLight]: "👉🏼", 
				[.medium]: "👉🏽", 
				[.mediumDark]: "👉🏾", 
				[.dark]: "👉🏿"
			],
			.fistedHandSign:[
				[.light]: "👊🏻", 
				[.mediumLight]: "👊🏼", 
				[.medium]: "👊🏽", 
				[.mediumDark]: "👊🏾", 
				[.dark]: "👊🏿"
			],
			.wavingHandSign:[
				[.light]: "👋🏻", 
				[.mediumLight]: "👋🏼", 
				[.medium]: "👋🏽", 
				[.mediumDark]: "👋🏾", 
				[.dark]: "👋🏿"
			],
			.okHandSign:[
				[.light]: "👌🏻", 
				[.mediumLight]: "👌🏼", 
				[.medium]: "👌🏽", 
				[.mediumDark]: "👌🏾", 
				[.dark]: "👌🏿"
			],
			.thumbsUpSign:[
				[.light]: "👍🏻", 
				[.mediumLight]: "👍🏼", 
				[.medium]: "👍🏽", 
				[.mediumDark]: "👍🏾", 
				[.dark]: "👍🏿"
			],
			.thumbsDownSign:[
				[.light]: "👎🏻", 
				[.mediumLight]: "👎🏼", 
				[.medium]: "👎🏽", 
				[.mediumDark]: "👎🏾", 
				[.dark]: "👎🏿"
			],
			.clappingHandsSign:[
				[.light]: "👏🏻", 
				[.mediumLight]: "👏🏼", 
				[.medium]: "👏🏽", 
				[.mediumDark]: "👏🏾", 
				[.dark]: "👏🏿"
			],
			.openHandsSign:[
				[.light]: "👐🏻", 
				[.mediumLight]: "👐🏼", 
				[.medium]: "👐🏽", 
				[.mediumDark]: "👐🏾", 
				[.dark]: "👐🏿"
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
			.manFarmer:[
				[.light]: "👨🏻‍🌾", 
				[.mediumLight]: "👨🏼‍🌾", 
				[.medium]: "👨🏽‍🌾", 
				[.mediumDark]: "👨🏾‍🌾", 
				[.dark]: "👨🏿‍🌾"
			],
			.manCook:[
				[.light]: "👨🏻‍🍳", 
				[.mediumLight]: "👨🏼‍🍳", 
				[.medium]: "👨🏽‍🍳", 
				[.mediumDark]: "👨🏾‍🍳", 
				[.dark]: "👨🏿‍🍳"
			],
			.manFeedingBaby:[
				[.light]: "👨🏻‍🍼", 
				[.mediumLight]: "👨🏼‍🍼", 
				[.medium]: "👨🏽‍🍼", 
				[.mediumDark]: "👨🏾‍🍼", 
				[.dark]: "👨🏿‍🍼"
			],
			.manStudent:[
				[.light]: "👨🏻‍🎓", 
				[.mediumLight]: "👨🏼‍🎓", 
				[.medium]: "👨🏽‍🎓", 
				[.mediumDark]: "👨🏾‍🎓", 
				[.dark]: "👨🏿‍🎓"
			],
			.manSinger:[
				[.light]: "👨🏻‍🎤", 
				[.mediumLight]: "👨🏼‍🎤", 
				[.medium]: "👨🏽‍🎤", 
				[.mediumDark]: "👨🏾‍🎤", 
				[.dark]: "👨🏿‍🎤"
			],
			.manArtist:[
				[.light]: "👨🏻‍🎨", 
				[.mediumLight]: "👨🏼‍🎨", 
				[.medium]: "👨🏽‍🎨", 
				[.mediumDark]: "👨🏾‍🎨", 
				[.dark]: "👨🏿‍🎨"
			],
			.manTeacher:[
				[.light]: "👨🏻‍🏫", 
				[.mediumLight]: "👨🏼‍🏫", 
				[.medium]: "👨🏽‍🏫", 
				[.mediumDark]: "👨🏾‍🏫", 
				[.dark]: "👨🏿‍🏫"
			],
			.manFactoryWorker:[
				[.light]: "👨🏻‍🏭", 
				[.mediumLight]: "👨🏼‍🏭", 
				[.medium]: "👨🏽‍🏭", 
				[.mediumDark]: "👨🏾‍🏭", 
				[.dark]: "👨🏿‍🏭"
			],
			.manTechnologist:[
				[.light]: "👨🏻‍💻", 
				[.mediumLight]: "👨🏼‍💻", 
				[.medium]: "👨🏽‍💻", 
				[.mediumDark]: "👨🏾‍💻", 
				[.dark]: "👨🏿‍💻"
			],
			.manOfficeWorker:[
				[.light]: "👨🏻‍💼", 
				[.mediumLight]: "👨🏼‍💼", 
				[.medium]: "👨🏽‍💼", 
				[.mediumDark]: "👨🏾‍💼", 
				[.dark]: "👨🏿‍💼"
			],
			.manMechanic:[
				[.light]: "👨🏻‍🔧", 
				[.mediumLight]: "👨🏼‍🔧", 
				[.medium]: "👨🏽‍🔧", 
				[.mediumDark]: "👨🏾‍🔧", 
				[.dark]: "👨🏿‍🔧"
			],
			.manScientist:[
				[.light]: "👨🏻‍🔬", 
				[.mediumLight]: "👨🏼‍🔬", 
				[.medium]: "👨🏽‍🔬", 
				[.mediumDark]: "👨🏾‍🔬", 
				[.dark]: "👨🏿‍🔬"
			],
			.manAstronaut:[
				[.light]: "👨🏻‍🚀", 
				[.mediumLight]: "👨🏼‍🚀", 
				[.medium]: "👨🏽‍🚀", 
				[.mediumDark]: "👨🏾‍🚀", 
				[.dark]: "👨🏿‍🚀"
			],
			.manFirefighter:[
				[.light]: "👨🏻‍🚒", 
				[.mediumLight]: "👨🏼‍🚒", 
				[.medium]: "👨🏽‍🚒", 
				[.mediumDark]: "👨🏾‍🚒", 
				[.dark]: "👨🏿‍🚒"
			],
			.manWithWhiteCaneFacingRight:[
				[.light]: "👨🏻‍🦯‍➡️", 
				[.mediumLight]: "👨🏼‍🦯‍➡️", 
				[.medium]: "👨🏽‍🦯‍➡️", 
				[.mediumDark]: "👨🏾‍🦯‍➡️", 
				[.dark]: "👨🏿‍🦯‍➡️"
			],
			.manWithWhiteCane:[
				[.light]: "👨🏻‍🦯", 
				[.mediumLight]: "👨🏼‍🦯", 
				[.medium]: "👨🏽‍🦯", 
				[.mediumDark]: "👨🏾‍🦯", 
				[.dark]: "👨🏿‍🦯"
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
			.manBald:[
				[.light]: "👨🏻‍🦲", 
				[.mediumLight]: "👨🏼‍🦲", 
				[.medium]: "👨🏽‍🦲", 
				[.mediumDark]: "👨🏾‍🦲", 
				[.dark]: "👨🏿‍🦲"
			],
			.manWhiteHair:[
				[.light]: "👨🏻‍🦳", 
				[.mediumLight]: "👨🏼‍🦳", 
				[.medium]: "👨🏽‍🦳", 
				[.mediumDark]: "👨🏾‍🦳", 
				[.dark]: "👨🏿‍🦳"
			],
			.manInMotorizedWheelchairFacingRight:[
				[.light]: "👨🏻‍🦼‍➡️", 
				[.mediumLight]: "👨🏼‍🦼‍➡️", 
				[.medium]: "👨🏽‍🦼‍➡️", 
				[.mediumDark]: "👨🏾‍🦼‍➡️", 
				[.dark]: "👨🏿‍🦼‍➡️"
			],
			.manInMotorizedWheelchair:[
				[.light]: "👨🏻‍🦼", 
				[.mediumLight]: "👨🏼‍🦼", 
				[.medium]: "👨🏽‍🦼", 
				[.mediumDark]: "👨🏾‍🦼", 
				[.dark]: "👨🏿‍🦼"
			],
			.manInManualWheelchairFacingRight:[
				[.light]: "👨🏻‍🦽‍➡️", 
				[.mediumLight]: "👨🏼‍🦽‍➡️", 
				[.medium]: "👨🏽‍🦽‍➡️", 
				[.mediumDark]: "👨🏾‍🦽‍➡️", 
				[.dark]: "👨🏿‍🦽‍➡️"
			],
			.manInManualWheelchair:[
				[.light]: "👨🏻‍🦽", 
				[.mediumLight]: "👨🏼‍🦽", 
				[.medium]: "👨🏽‍🦽", 
				[.mediumDark]: "👨🏾‍🦽", 
				[.dark]: "👨🏿‍🦽"
			],
			.manHealthWorker:[
				[.light]: "👨🏻‍⚕️", 
				[.mediumLight]: "👨🏼‍⚕️", 
				[.medium]: "👨🏽‍⚕️", 
				[.mediumDark]: "👨🏾‍⚕️", 
				[.dark]: "👨🏿‍⚕️"
			],
			.manJudge:[
				[.light]: "👨🏻‍⚖️", 
				[.mediumLight]: "👨🏼‍⚖️", 
				[.medium]: "👨🏽‍⚖️", 
				[.mediumDark]: "👨🏾‍⚖️", 
				[.dark]: "👨🏿‍⚖️"
			],
			.manPilot:[
				[.light]: "👨🏻‍✈️", 
				[.mediumLight]: "👨🏼‍✈️", 
				[.medium]: "👨🏽‍✈️", 
				[.mediumDark]: "👨🏾‍✈️", 
				[.dark]: "👨🏿‍✈️"
			],
			.coupleWithHeartManMan:[
				[.light, .light]: "👨🏻‍❤️‍👨🏻", 
				[.light, .mediumLight]: "👨🏻‍❤️‍👨🏼", 
				[.light, .medium]: "👨🏻‍❤️‍👨🏽", 
				[.light, .mediumDark]: "👨🏻‍❤️‍👨🏾", 
				[.light, .dark]: "👨🏻‍❤️‍👨🏿", 
				[.mediumLight, .light]: "👨🏼‍❤️‍👨🏻", 
				[.mediumLight, .mediumLight]: "👨🏼‍❤️‍👨🏼", 
				[.mediumLight, .medium]: "👨🏼‍❤️‍👨🏽", 
				[.mediumLight, .mediumDark]: "👨🏼‍❤️‍👨🏾", 
				[.mediumLight, .dark]: "👨🏼‍❤️‍👨🏿", 
				[.medium, .light]: "👨🏽‍❤️‍👨🏻", 
				[.medium, .mediumLight]: "👨🏽‍❤️‍👨🏼", 
				[.medium, .medium]: "👨🏽‍❤️‍👨🏽", 
				[.medium, .mediumDark]: "👨🏽‍❤️‍👨🏾", 
				[.medium, .dark]: "👨🏽‍❤️‍👨🏿", 
				[.mediumDark, .light]: "👨🏾‍❤️‍👨🏻", 
				[.mediumDark, .mediumLight]: "👨🏾‍❤️‍👨🏼", 
				[.mediumDark, .medium]: "👨🏾‍❤️‍👨🏽", 
				[.mediumDark, .mediumDark]: "👨🏾‍❤️‍👨🏾", 
				[.mediumDark, .dark]: "👨🏾‍❤️‍👨🏿", 
				[.dark, .light]: "👨🏿‍❤️‍👨🏻", 
				[.dark, .mediumLight]: "👨🏿‍❤️‍👨🏼", 
				[.dark, .medium]: "👨🏿‍❤️‍👨🏽", 
				[.dark, .mediumDark]: "👨🏿‍❤️‍👨🏾", 
				[.dark, .dark]: "👨🏿‍❤️‍👨🏿"
			],
			.kissManMan:[
				[.light, .light]: "👨🏻‍❤️‍💋‍👨🏻", 
				[.light, .mediumLight]: "👨🏻‍❤️‍💋‍👨🏼", 
				[.light, .medium]: "👨🏻‍❤️‍💋‍👨🏽", 
				[.light, .mediumDark]: "👨🏻‍❤️‍💋‍👨🏾", 
				[.light, .dark]: "👨🏻‍❤️‍💋‍👨🏿", 
				[.mediumLight, .light]: "👨🏼‍❤️‍💋‍👨🏻", 
				[.mediumLight, .mediumLight]: "👨🏼‍❤️‍💋‍👨🏼", 
				[.mediumLight, .medium]: "👨🏼‍❤️‍💋‍👨🏽", 
				[.mediumLight, .mediumDark]: "👨🏼‍❤️‍💋‍👨🏾", 
				[.mediumLight, .dark]: "👨🏼‍❤️‍💋‍👨🏿", 
				[.medium, .light]: "👨🏽‍❤️‍💋‍👨🏻", 
				[.medium, .mediumLight]: "👨🏽‍❤️‍💋‍👨🏼", 
				[.medium, .medium]: "👨🏽‍❤️‍💋‍👨🏽", 
				[.medium, .mediumDark]: "👨🏽‍❤️‍💋‍👨🏾", 
				[.medium, .dark]: "👨🏽‍❤️‍💋‍👨🏿", 
				[.mediumDark, .light]: "👨🏾‍❤️‍💋‍👨🏻", 
				[.mediumDark, .mediumLight]: "👨🏾‍❤️‍💋‍👨🏼", 
				[.mediumDark, .medium]: "👨🏾‍❤️‍💋‍👨🏽", 
				[.mediumDark, .mediumDark]: "👨🏾‍❤️‍💋‍👨🏾", 
				[.mediumDark, .dark]: "👨🏾‍❤️‍💋‍👨🏿", 
				[.dark, .light]: "👨🏿‍❤️‍💋‍👨🏻", 
				[.dark, .mediumLight]: "👨🏿‍❤️‍💋‍👨🏼", 
				[.dark, .medium]: "👨🏿‍❤️‍💋‍👨🏽", 
				[.dark, .mediumDark]: "👨🏿‍❤️‍💋‍👨🏾", 
				[.dark, .dark]: "👨🏿‍❤️‍💋‍👨🏿"
			],
			.man:[
				[.light]: "👨🏻", 
				[.mediumLight]: "👨🏼", 
				[.medium]: "👨🏽", 
				[.mediumDark]: "👨🏾", 
				[.dark]: "👨🏿"
			],
			.womanFarmer:[
				[.light]: "👩🏻‍🌾", 
				[.mediumLight]: "👩🏼‍🌾", 
				[.medium]: "👩🏽‍🌾", 
				[.mediumDark]: "👩🏾‍🌾", 
				[.dark]: "👩🏿‍🌾"
			],
			.womanCook:[
				[.light]: "👩🏻‍🍳", 
				[.mediumLight]: "👩🏼‍🍳", 
				[.medium]: "👩🏽‍🍳", 
				[.mediumDark]: "👩🏾‍🍳", 
				[.dark]: "👩🏿‍🍳"
			],
			.womanFeedingBaby:[
				[.light]: "👩🏻‍🍼", 
				[.mediumLight]: "👩🏼‍🍼", 
				[.medium]: "👩🏽‍🍼", 
				[.mediumDark]: "👩🏾‍🍼", 
				[.dark]: "👩🏿‍🍼"
			],
			.womanStudent:[
				[.light]: "👩🏻‍🎓", 
				[.mediumLight]: "👩🏼‍🎓", 
				[.medium]: "👩🏽‍🎓", 
				[.mediumDark]: "👩🏾‍🎓", 
				[.dark]: "👩🏿‍🎓"
			],
			.womanSinger:[
				[.light]: "👩🏻‍🎤", 
				[.mediumLight]: "👩🏼‍🎤", 
				[.medium]: "👩🏽‍🎤", 
				[.mediumDark]: "👩🏾‍🎤", 
				[.dark]: "👩🏿‍🎤"
			],
			.womanArtist:[
				[.light]: "👩🏻‍🎨", 
				[.mediumLight]: "👩🏼‍🎨", 
				[.medium]: "👩🏽‍🎨", 
				[.mediumDark]: "👩🏾‍🎨", 
				[.dark]: "👩🏿‍🎨"
			],
			.womanTeacher:[
				[.light]: "👩🏻‍🏫", 
				[.mediumLight]: "👩🏼‍🏫", 
				[.medium]: "👩🏽‍🏫", 
				[.mediumDark]: "👩🏾‍🏫", 
				[.dark]: "👩🏿‍🏫"
			],
			.womanFactoryWorker:[
				[.light]: "👩🏻‍🏭", 
				[.mediumLight]: "👩🏼‍🏭", 
				[.medium]: "👩🏽‍🏭", 
				[.mediumDark]: "👩🏾‍🏭", 
				[.dark]: "👩🏿‍🏭"
			],
			.womanTechnologist:[
				[.light]: "👩🏻‍💻", 
				[.mediumLight]: "👩🏼‍💻", 
				[.medium]: "👩🏽‍💻", 
				[.mediumDark]: "👩🏾‍💻", 
				[.dark]: "👩🏿‍💻"
			],
			.womanOfficeWorker:[
				[.light]: "👩🏻‍💼", 
				[.mediumLight]: "👩🏼‍💼", 
				[.medium]: "👩🏽‍💼", 
				[.mediumDark]: "👩🏾‍💼", 
				[.dark]: "👩🏿‍💼"
			],
			.womanMechanic:[
				[.light]: "👩🏻‍🔧", 
				[.mediumLight]: "👩🏼‍🔧", 
				[.medium]: "👩🏽‍🔧", 
				[.mediumDark]: "👩🏾‍🔧", 
				[.dark]: "👩🏿‍🔧"
			],
			.womanScientist:[
				[.light]: "👩🏻‍🔬", 
				[.mediumLight]: "👩🏼‍🔬", 
				[.medium]: "👩🏽‍🔬", 
				[.mediumDark]: "👩🏾‍🔬", 
				[.dark]: "👩🏿‍🔬"
			],
			.womanAstronaut:[
				[.light]: "👩🏻‍🚀", 
				[.mediumLight]: "👩🏼‍🚀", 
				[.medium]: "👩🏽‍🚀", 
				[.mediumDark]: "👩🏾‍🚀", 
				[.dark]: "👩🏿‍🚀"
			],
			.womanFirefighter:[
				[.light]: "👩🏻‍🚒", 
				[.mediumLight]: "👩🏼‍🚒", 
				[.medium]: "👩🏽‍🚒", 
				[.mediumDark]: "👩🏾‍🚒", 
				[.dark]: "👩🏿‍🚒"
			],
			.womanWithWhiteCaneFacingRight:[
				[.light]: "👩🏻‍🦯‍➡️", 
				[.mediumLight]: "👩🏼‍🦯‍➡️", 
				[.medium]: "👩🏽‍🦯‍➡️", 
				[.mediumDark]: "👩🏾‍🦯‍➡️", 
				[.dark]: "👩🏿‍🦯‍➡️"
			],
			.womanWithWhiteCane:[
				[.light]: "👩🏻‍🦯", 
				[.mediumLight]: "👩🏼‍🦯", 
				[.medium]: "👩🏽‍🦯", 
				[.mediumDark]: "👩🏾‍🦯", 
				[.dark]: "👩🏿‍🦯"
			],
			.womanRedHair:[
				[.light]: "👩🏻‍🦰", 
				[.mediumLight]: "👩🏼‍🦰", 
				[.medium]: "👩🏽‍🦰", 
				[.mediumDark]: "👩🏾‍🦰", 
				[.dark]: "👩🏿‍🦰"
			],
			.womanCurlyHair:[
				[.light]: "👩🏻‍🦱", 
				[.mediumLight]: "👩🏼‍🦱", 
				[.medium]: "👩🏽‍🦱", 
				[.mediumDark]: "👩🏾‍🦱", 
				[.dark]: "👩🏿‍🦱"
			],
			.womanBald:[
				[.light]: "👩🏻‍🦲", 
				[.mediumLight]: "👩🏼‍🦲", 
				[.medium]: "👩🏽‍🦲", 
				[.mediumDark]: "👩🏾‍🦲", 
				[.dark]: "👩🏿‍🦲"
			],
			.womanWhiteHair:[
				[.light]: "👩🏻‍🦳", 
				[.mediumLight]: "👩🏼‍🦳", 
				[.medium]: "👩🏽‍🦳", 
				[.mediumDark]: "👩🏾‍🦳", 
				[.dark]: "👩🏿‍🦳"
			],
			.womanInMotorizedWheelchairFacingRight:[
				[.light]: "👩🏻‍🦼‍➡️", 
				[.mediumLight]: "👩🏼‍🦼‍➡️", 
				[.medium]: "👩🏽‍🦼‍➡️", 
				[.mediumDark]: "👩🏾‍🦼‍➡️", 
				[.dark]: "👩🏿‍🦼‍➡️"
			],
			.womanInMotorizedWheelchair:[
				[.light]: "👩🏻‍🦼", 
				[.mediumLight]: "👩🏼‍🦼", 
				[.medium]: "👩🏽‍🦼", 
				[.mediumDark]: "👩🏾‍🦼", 
				[.dark]: "👩🏿‍🦼"
			],
			.womanInManualWheelchairFacingRight:[
				[.light]: "👩🏻‍🦽‍➡️", 
				[.mediumLight]: "👩🏼‍🦽‍➡️", 
				[.medium]: "👩🏽‍🦽‍➡️", 
				[.mediumDark]: "👩🏾‍🦽‍➡️", 
				[.dark]: "👩🏿‍🦽‍➡️"
			],
			.womanInManualWheelchair:[
				[.light]: "👩🏻‍🦽", 
				[.mediumLight]: "👩🏼‍🦽", 
				[.medium]: "👩🏽‍🦽", 
				[.mediumDark]: "👩🏾‍🦽", 
				[.dark]: "👩🏿‍🦽"
			],
			.womanHealthWorker:[
				[.light]: "👩🏻‍⚕️", 
				[.mediumLight]: "👩🏼‍⚕️", 
				[.medium]: "👩🏽‍⚕️", 
				[.mediumDark]: "👩🏾‍⚕️", 
				[.dark]: "👩🏿‍⚕️"
			],
			.womanJudge:[
				[.light]: "👩🏻‍⚖️", 
				[.mediumLight]: "👩🏼‍⚖️", 
				[.medium]: "👩🏽‍⚖️", 
				[.mediumDark]: "👩🏾‍⚖️", 
				[.dark]: "👩🏿‍⚖️"
			],
			.womanPilot:[
				[.light]: "👩🏻‍✈️", 
				[.mediumLight]: "👩🏼‍✈️", 
				[.medium]: "👩🏽‍✈️", 
				[.mediumDark]: "👩🏾‍✈️", 
				[.dark]: "👩🏿‍✈️"
			],
			.coupleWithHeartWomanMan:[
				[.light, .light]: "👩🏻‍❤️‍👨🏻", 
				[.light, .mediumLight]: "👩🏻‍❤️‍👨🏼", 
				[.light, .medium]: "👩🏻‍❤️‍👨🏽", 
				[.light, .mediumDark]: "👩🏻‍❤️‍👨🏾", 
				[.light, .dark]: "👩🏻‍❤️‍👨🏿", 
				[.mediumLight, .light]: "👩🏼‍❤️‍👨🏻", 
				[.mediumLight, .mediumLight]: "👩🏼‍❤️‍👨🏼", 
				[.mediumLight, .medium]: "👩🏼‍❤️‍👨🏽", 
				[.mediumLight, .mediumDark]: "👩🏼‍❤️‍👨🏾", 
				[.mediumLight, .dark]: "👩🏼‍❤️‍👨🏿", 
				[.medium, .light]: "👩🏽‍❤️‍👨🏻", 
				[.medium, .mediumLight]: "👩🏽‍❤️‍👨🏼", 
				[.medium, .medium]: "👩🏽‍❤️‍👨🏽", 
				[.medium, .mediumDark]: "👩🏽‍❤️‍👨🏾", 
				[.medium, .dark]: "👩🏽‍❤️‍👨🏿", 
				[.mediumDark, .light]: "👩🏾‍❤️‍👨🏻", 
				[.mediumDark, .mediumLight]: "👩🏾‍❤️‍👨🏼", 
				[.mediumDark, .medium]: "👩🏾‍❤️‍👨🏽", 
				[.mediumDark, .mediumDark]: "👩🏾‍❤️‍👨🏾", 
				[.mediumDark, .dark]: "👩🏾‍❤️‍👨🏿", 
				[.dark, .light]: "👩🏿‍❤️‍👨🏻", 
				[.dark, .mediumLight]: "👩🏿‍❤️‍👨🏼", 
				[.dark, .medium]: "👩🏿‍❤️‍👨🏽", 
				[.dark, .mediumDark]: "👩🏿‍❤️‍👨🏾", 
				[.dark, .dark]: "👩🏿‍❤️‍👨🏿"
			],
			.coupleWithHeartWomanWoman:[
				[.light, .light]: "👩🏻‍❤️‍👩🏻", 
				[.light, .mediumLight]: "👩🏻‍❤️‍👩🏼", 
				[.light, .medium]: "👩🏻‍❤️‍👩🏽", 
				[.light, .mediumDark]: "👩🏻‍❤️‍👩🏾", 
				[.light, .dark]: "👩🏻‍❤️‍👩🏿", 
				[.mediumLight, .light]: "👩🏼‍❤️‍👩🏻", 
				[.mediumLight, .mediumLight]: "👩🏼‍❤️‍👩🏼", 
				[.mediumLight, .medium]: "👩🏼‍❤️‍👩🏽", 
				[.mediumLight, .mediumDark]: "👩🏼‍❤️‍👩🏾", 
				[.mediumLight, .dark]: "👩🏼‍❤️‍👩🏿", 
				[.medium, .light]: "👩🏽‍❤️‍👩🏻", 
				[.medium, .mediumLight]: "👩🏽‍❤️‍👩🏼", 
				[.medium, .medium]: "👩🏽‍❤️‍👩🏽", 
				[.medium, .mediumDark]: "👩🏽‍❤️‍👩🏾", 
				[.medium, .dark]: "👩🏽‍❤️‍👩🏿", 
				[.mediumDark, .light]: "👩🏾‍❤️‍👩🏻", 
				[.mediumDark, .mediumLight]: "👩🏾‍❤️‍👩🏼", 
				[.mediumDark, .medium]: "👩🏾‍❤️‍👩🏽", 
				[.mediumDark, .mediumDark]: "👩🏾‍❤️‍👩🏾", 
				[.mediumDark, .dark]: "👩🏾‍❤️‍👩🏿", 
				[.dark, .light]: "👩🏿‍❤️‍👩🏻", 
				[.dark, .mediumLight]: "👩🏿‍❤️‍👩🏼", 
				[.dark, .medium]: "👩🏿‍❤️‍👩🏽", 
				[.dark, .mediumDark]: "👩🏿‍❤️‍👩🏾", 
				[.dark, .dark]: "👩🏿‍❤️‍👩🏿"
			],
			.kissWomanMan:[
				[.light, .light]: "👩🏻‍❤️‍💋‍👨🏻", 
				[.light, .mediumLight]: "👩🏻‍❤️‍💋‍👨🏼", 
				[.light, .medium]: "👩🏻‍❤️‍💋‍👨🏽", 
				[.light, .mediumDark]: "👩🏻‍❤️‍💋‍👨🏾", 
				[.light, .dark]: "👩🏻‍❤️‍💋‍👨🏿", 
				[.mediumLight, .light]: "👩🏼‍❤️‍💋‍👨🏻", 
				[.mediumLight, .mediumLight]: "👩🏼‍❤️‍💋‍👨🏼", 
				[.mediumLight, .medium]: "👩🏼‍❤️‍💋‍👨🏽", 
				[.mediumLight, .mediumDark]: "👩🏼‍❤️‍💋‍👨🏾", 
				[.mediumLight, .dark]: "👩🏼‍❤️‍💋‍👨🏿", 
				[.medium, .light]: "👩🏽‍❤️‍💋‍👨🏻", 
				[.medium, .mediumLight]: "👩🏽‍❤️‍💋‍👨🏼", 
				[.medium, .medium]: "👩🏽‍❤️‍💋‍👨🏽", 
				[.medium, .mediumDark]: "👩🏽‍❤️‍💋‍👨🏾", 
				[.medium, .dark]: "👩🏽‍❤️‍💋‍👨🏿", 
				[.mediumDark, .light]: "👩🏾‍❤️‍💋‍👨🏻", 
				[.mediumDark, .mediumLight]: "👩🏾‍❤️‍💋‍👨🏼", 
				[.mediumDark, .medium]: "👩🏾‍❤️‍💋‍👨🏽", 
				[.mediumDark, .mediumDark]: "👩🏾‍❤️‍💋‍👨🏾", 
				[.mediumDark, .dark]: "👩🏾‍❤️‍💋‍👨🏿", 
				[.dark, .light]: "👩🏿‍❤️‍💋‍👨🏻", 
				[.dark, .mediumLight]: "👩🏿‍❤️‍💋‍👨🏼", 
				[.dark, .medium]: "👩🏿‍❤️‍💋‍👨🏽", 
				[.dark, .mediumDark]: "👩🏿‍❤️‍💋‍👨🏾", 
				[.dark, .dark]: "👩🏿‍❤️‍💋‍👨🏿"
			],
			.kissWomanWoman:[
				[.light, .light]: "👩🏻‍❤️‍💋‍👩🏻", 
				[.light, .mediumLight]: "👩🏻‍❤️‍💋‍👩🏼", 
				[.light, .medium]: "👩🏻‍❤️‍💋‍👩🏽", 
				[.light, .mediumDark]: "👩🏻‍❤️‍💋‍👩🏾", 
				[.light, .dark]: "👩🏻‍❤️‍💋‍👩🏿", 
				[.mediumLight, .light]: "👩🏼‍❤️‍💋‍👩🏻", 
				[.mediumLight, .mediumLight]: "👩🏼‍❤️‍💋‍👩🏼", 
				[.mediumLight, .medium]: "👩🏼‍❤️‍💋‍👩🏽", 
				[.mediumLight, .mediumDark]: "👩🏼‍❤️‍💋‍👩🏾", 
				[.mediumLight, .dark]: "👩🏼‍❤️‍💋‍👩🏿", 
				[.medium, .light]: "👩🏽‍❤️‍💋‍👩🏻", 
				[.medium, .mediumLight]: "👩🏽‍❤️‍💋‍👩🏼", 
				[.medium, .medium]: "👩🏽‍❤️‍💋‍👩🏽", 
				[.medium, .mediumDark]: "👩🏽‍❤️‍💋‍👩🏾", 
				[.medium, .dark]: "👩🏽‍❤️‍💋‍👩🏿", 
				[.mediumDark, .light]: "👩🏾‍❤️‍💋‍👩🏻", 
				[.mediumDark, .mediumLight]: "👩🏾‍❤️‍💋‍👩🏼", 
				[.mediumDark, .medium]: "👩🏾‍❤️‍💋‍👩🏽", 
				[.mediumDark, .mediumDark]: "👩🏾‍❤️‍💋‍👩🏾", 
				[.mediumDark, .dark]: "👩🏾‍❤️‍💋‍👩🏿", 
				[.dark, .light]: "👩🏿‍❤️‍💋‍👩🏻", 
				[.dark, .mediumLight]: "👩🏿‍❤️‍💋‍👩🏼", 
				[.dark, .medium]: "👩🏿‍❤️‍💋‍👩🏽", 
				[.dark, .mediumDark]: "👩🏿‍❤️‍💋‍👩🏾", 
				[.dark, .dark]: "👩🏿‍❤️‍💋‍👩🏿"
			],
			.woman:[
				[.light]: "👩🏻", 
				[.mediumLight]: "👩🏼", 
				[.medium]: "👩🏽", 
				[.mediumDark]: "👩🏾", 
				[.dark]: "👩🏿"
			],
			.manAndWomanHoldingHands:[
				[.light]: "👫🏻", 
				[.mediumLight]: "👫🏼", 
				[.medium]: "👫🏽", 
				[.mediumDark]: "👫🏾", 
				[.dark]: "👫🏿", 
				[.light, .mediumLight]: "👩🏻‍🤝‍👨🏼", 
				[.light, .medium]: "👩🏻‍🤝‍👨🏽", 
				[.light, .mediumDark]: "👩🏻‍🤝‍👨🏾", 
				[.light, .dark]: "👩🏻‍🤝‍👨🏿", 
				[.mediumLight, .light]: "👩🏼‍🤝‍👨🏻", 
				[.mediumLight, .medium]: "👩🏼‍🤝‍👨🏽", 
				[.mediumLight, .mediumDark]: "👩🏼‍🤝‍👨🏾", 
				[.mediumLight, .dark]: "👩🏼‍🤝‍👨🏿", 
				[.medium, .light]: "👩🏽‍🤝‍👨🏻", 
				[.medium, .mediumLight]: "👩🏽‍🤝‍👨🏼", 
				[.medium, .mediumDark]: "👩🏽‍🤝‍👨🏾", 
				[.medium, .dark]: "👩🏽‍🤝‍👨🏿", 
				[.mediumDark, .light]: "👩🏾‍🤝‍👨🏻", 
				[.mediumDark, .mediumLight]: "👩🏾‍🤝‍👨🏼", 
				[.mediumDark, .medium]: "👩🏾‍🤝‍👨🏽", 
				[.mediumDark, .dark]: "👩🏾‍🤝‍👨🏿", 
				[.dark, .light]: "👩🏿‍🤝‍👨🏻", 
				[.dark, .mediumLight]: "👩🏿‍🤝‍👨🏼", 
				[.dark, .medium]: "👩🏿‍🤝‍👨🏽", 
				[.dark, .mediumDark]: "👩🏿‍🤝‍👨🏾"
			],
			.twoMenHoldingHands:[
				[.light]: "👬🏻", 
				[.mediumLight]: "👬🏼", 
				[.medium]: "👬🏽", 
				[.mediumDark]: "👬🏾", 
				[.dark]: "👬🏿", 
				[.light, .mediumLight]: "👨🏻‍🤝‍👨🏼", 
				[.light, .medium]: "👨🏻‍🤝‍👨🏽", 
				[.light, .mediumDark]: "👨🏻‍🤝‍👨🏾", 
				[.light, .dark]: "👨🏻‍🤝‍👨🏿", 
				[.mediumLight, .light]: "👨🏼‍🤝‍👨🏻", 
				[.mediumLight, .medium]: "👨🏼‍🤝‍👨🏽", 
				[.mediumLight, .mediumDark]: "👨🏼‍🤝‍👨🏾", 
				[.mediumLight, .dark]: "👨🏼‍🤝‍👨🏿", 
				[.medium, .light]: "👨🏽‍🤝‍👨🏻", 
				[.medium, .mediumLight]: "👨🏽‍🤝‍👨🏼", 
				[.medium, .mediumDark]: "👨🏽‍🤝‍👨🏾", 
				[.medium, .dark]: "👨🏽‍🤝‍👨🏿", 
				[.mediumDark, .light]: "👨🏾‍🤝‍👨🏻", 
				[.mediumDark, .mediumLight]: "👨🏾‍🤝‍👨🏼", 
				[.mediumDark, .medium]: "👨🏾‍🤝‍👨🏽", 
				[.mediumDark, .dark]: "👨🏾‍🤝‍👨🏿", 
				[.dark, .light]: "👨🏿‍🤝‍👨🏻", 
				[.dark, .mediumLight]: "👨🏿‍🤝‍👨🏼", 
				[.dark, .medium]: "👨🏿‍🤝‍👨🏽", 
				[.dark, .mediumDark]: "👨🏿‍🤝‍👨🏾"
			],
			.twoWomenHoldingHands:[
				[.light]: "👭🏻", 
				[.mediumLight]: "👭🏼", 
				[.medium]: "👭🏽", 
				[.mediumDark]: "👭🏾", 
				[.dark]: "👭🏿", 
				[.light, .mediumLight]: "👩🏻‍🤝‍👩🏼", 
				[.light, .medium]: "👩🏻‍🤝‍👩🏽", 
				[.light, .mediumDark]: "👩🏻‍🤝‍👩🏾", 
				[.light, .dark]: "👩🏻‍🤝‍👩🏿", 
				[.mediumLight, .light]: "👩🏼‍🤝‍👩🏻", 
				[.mediumLight, .medium]: "👩🏼‍🤝‍👩🏽", 
				[.mediumLight, .mediumDark]: "👩🏼‍🤝‍👩🏾", 
				[.mediumLight, .dark]: "👩🏼‍🤝‍👩🏿", 
				[.medium, .light]: "👩🏽‍🤝‍👩🏻", 
				[.medium, .mediumLight]: "👩🏽‍🤝‍👩🏼", 
				[.medium, .mediumDark]: "👩🏽‍🤝‍👩🏾", 
				[.medium, .dark]: "👩🏽‍🤝‍👩🏿", 
				[.mediumDark, .light]: "👩🏾‍🤝‍👩🏻", 
				[.mediumDark, .mediumLight]: "👩🏾‍🤝‍👩🏼", 
				[.mediumDark, .medium]: "👩🏾‍🤝‍👩🏽", 
				[.mediumDark, .dark]: "👩🏾‍🤝‍👩🏿", 
				[.dark, .light]: "👩🏿‍🤝‍👩🏻", 
				[.dark, .mediumLight]: "👩🏿‍🤝‍👩🏼", 
				[.dark, .medium]: "👩🏿‍🤝‍👩🏽", 
				[.dark, .mediumDark]: "👩🏿‍🤝‍👩🏾"
			],
			.womanPoliceOfficer:[
				[.light]: "👮🏻‍♀️", 
				[.mediumLight]: "👮🏼‍♀️", 
				[.medium]: "👮🏽‍♀️", 
				[.mediumDark]: "👮🏾‍♀️", 
				[.dark]: "👮🏿‍♀️"
			],
			.manPoliceOfficer:[
				[.light]: "👮🏻‍♂️", 
				[.mediumLight]: "👮🏼‍♂️", 
				[.medium]: "👮🏽‍♂️", 
				[.mediumDark]: "👮🏾‍♂️", 
				[.dark]: "👮🏿‍♂️"
			],
			.policeOfficer:[
				[.light]: "👮🏻", 
				[.mediumLight]: "👮🏼", 
				[.medium]: "👮🏽", 
				[.mediumDark]: "👮🏾", 
				[.dark]: "👮🏿"
			],
			.womanWithVeil:[
				[.light]: "👰🏻‍♀️", 
				[.mediumLight]: "👰🏼‍♀️", 
				[.medium]: "👰🏽‍♀️", 
				[.mediumDark]: "👰🏾‍♀️", 
				[.dark]: "👰🏿‍♀️"
			],
			.manWithVeil:[
				[.light]: "👰🏻‍♂️", 
				[.mediumLight]: "👰🏼‍♂️", 
				[.medium]: "👰🏽‍♂️", 
				[.mediumDark]: "👰🏾‍♂️", 
				[.dark]: "👰🏿‍♂️"
			],
			.brideWithVeil:[
				[.light]: "👰🏻", 
				[.mediumLight]: "👰🏼", 
				[.medium]: "👰🏽", 
				[.mediumDark]: "👰🏾", 
				[.dark]: "👰🏿"
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
			.personWithBlondHair:[
				[.light]: "👱🏻", 
				[.mediumLight]: "👱🏼", 
				[.medium]: "👱🏽", 
				[.mediumDark]: "👱🏾", 
				[.dark]: "👱🏿"
			],
			.manWithGuaPiMao:[
				[.light]: "👲🏻", 
				[.mediumLight]: "👲🏼", 
				[.medium]: "👲🏽", 
				[.mediumDark]: "👲🏾", 
				[.dark]: "👲🏿"
			],
			.womanWearingTurban:[
				[.light]: "👳🏻‍♀️", 
				[.mediumLight]: "👳🏼‍♀️", 
				[.medium]: "👳🏽‍♀️", 
				[.mediumDark]: "👳🏾‍♀️", 
				[.dark]: "👳🏿‍♀️"
			],
			.manWearingTurban:[
				[.light]: "👳🏻‍♂️", 
				[.mediumLight]: "👳🏼‍♂️", 
				[.medium]: "👳🏽‍♂️", 
				[.mediumDark]: "👳🏾‍♂️", 
				[.dark]: "👳🏿‍♂️"
			],
			.manWithTurban:[
				[.light]: "👳🏻", 
				[.mediumLight]: "👳🏼", 
				[.medium]: "👳🏽", 
				[.mediumDark]: "👳🏾", 
				[.dark]: "👳🏿"
			],
			.olderMan:[
				[.light]: "👴🏻", 
				[.mediumLight]: "👴🏼", 
				[.medium]: "👴🏽", 
				[.mediumDark]: "👴🏾", 
				[.dark]: "👴🏿"
			],
			.olderWoman:[
				[.light]: "👵🏻", 
				[.mediumLight]: "👵🏼", 
				[.medium]: "👵🏽", 
				[.mediumDark]: "👵🏾", 
				[.dark]: "👵🏿"
			],
			.baby:[
				[.light]: "👶🏻", 
				[.mediumLight]: "👶🏼", 
				[.medium]: "👶🏽", 
				[.mediumDark]: "👶🏾", 
				[.dark]: "👶🏿"
			],
			.womanConstructionWorker:[
				[.light]: "👷🏻‍♀️", 
				[.mediumLight]: "👷🏼‍♀️", 
				[.medium]: "👷🏽‍♀️", 
				[.mediumDark]: "👷🏾‍♀️", 
				[.dark]: "👷🏿‍♀️"
			],
			.manConstructionWorker:[
				[.light]: "👷🏻‍♂️", 
				[.mediumLight]: "👷🏼‍♂️", 
				[.medium]: "👷🏽‍♂️", 
				[.mediumDark]: "👷🏾‍♂️", 
				[.dark]: "👷🏿‍♂️"
			],
			.constructionWorker:[
				[.light]: "👷🏻", 
				[.mediumLight]: "👷🏼", 
				[.medium]: "👷🏽", 
				[.mediumDark]: "👷🏾", 
				[.dark]: "👷🏿"
			],
			.princess:[
				[.light]: "👸🏻", 
				[.mediumLight]: "👸🏼", 
				[.medium]: "👸🏽", 
				[.mediumDark]: "👸🏾", 
				[.dark]: "👸🏿"
			],
			.babyAngel:[
				[.light]: "👼🏻", 
				[.mediumLight]: "👼🏼", 
				[.medium]: "👼🏽", 
				[.mediumDark]: "👼🏾", 
				[.dark]: "👼🏿"
			],
			.womanTippingHand:[
				[.light]: "💁🏻‍♀️", 
				[.mediumLight]: "💁🏼‍♀️", 
				[.medium]: "💁🏽‍♀️", 
				[.mediumDark]: "💁🏾‍♀️", 
				[.dark]: "💁🏿‍♀️"
			],
			.manTippingHand:[
				[.light]: "💁🏻‍♂️", 
				[.mediumLight]: "💁🏼‍♂️", 
				[.medium]: "💁🏽‍♂️", 
				[.mediumDark]: "💁🏾‍♂️", 
				[.dark]: "💁🏿‍♂️"
			],
			.informationDeskPerson:[
				[.light]: "💁🏻", 
				[.mediumLight]: "💁🏼", 
				[.medium]: "💁🏽", 
				[.mediumDark]: "💁🏾", 
				[.dark]: "💁🏿"
			],
			.womanGuard:[
				[.light]: "💂🏻‍♀️", 
				[.mediumLight]: "💂🏼‍♀️", 
				[.medium]: "💂🏽‍♀️", 
				[.mediumDark]: "💂🏾‍♀️", 
				[.dark]: "💂🏿‍♀️"
			],
			.manGuard:[
				[.light]: "💂🏻‍♂️", 
				[.mediumLight]: "💂🏼‍♂️", 
				[.medium]: "💂🏽‍♂️", 
				[.mediumDark]: "💂🏾‍♂️", 
				[.dark]: "💂🏿‍♂️"
			],
			.guardsman:[
				[.light]: "💂🏻", 
				[.mediumLight]: "💂🏼", 
				[.medium]: "💂🏽", 
				[.mediumDark]: "💂🏾", 
				[.dark]: "💂🏿"
			],
			.dancer:[
				[.light]: "💃🏻", 
				[.mediumLight]: "💃🏼", 
				[.medium]: "💃🏽", 
				[.mediumDark]: "💃🏾", 
				[.dark]: "💃🏿"
			],
			.nailPolish:[
				[.light]: "💅🏻", 
				[.mediumLight]: "💅🏼", 
				[.medium]: "💅🏽", 
				[.mediumDark]: "💅🏾", 
				[.dark]: "💅🏿"
			],
			.womanGettingMassage:[
				[.light]: "💆🏻‍♀️", 
				[.mediumLight]: "💆🏼‍♀️", 
				[.medium]: "💆🏽‍♀️", 
				[.mediumDark]: "💆🏾‍♀️", 
				[.dark]: "💆🏿‍♀️"
			],
			.manGettingMassage:[
				[.light]: "💆🏻‍♂️", 
				[.mediumLight]: "💆🏼‍♂️", 
				[.medium]: "💆🏽‍♂️", 
				[.mediumDark]: "💆🏾‍♂️", 
				[.dark]: "💆🏿‍♂️"
			],
			.faceMassage:[
				[.light]: "💆🏻", 
				[.mediumLight]: "💆🏼", 
				[.medium]: "💆🏽", 
				[.mediumDark]: "💆🏾", 
				[.dark]: "💆🏿"
			],
			.womanGettingHaircut:[
				[.light]: "💇🏻‍♀️", 
				[.mediumLight]: "💇🏼‍♀️", 
				[.medium]: "💇🏽‍♀️", 
				[.mediumDark]: "💇🏾‍♀️", 
				[.dark]: "💇🏿‍♀️"
			],
			.manGettingHaircut:[
				[.light]: "💇🏻‍♂️", 
				[.mediumLight]: "💇🏼‍♂️", 
				[.medium]: "💇🏽‍♂️", 
				[.mediumDark]: "💇🏾‍♂️", 
				[.dark]: "💇🏿‍♂️"
			],
			.haircut:[
				[.light]: "💇🏻", 
				[.mediumLight]: "💇🏼", 
				[.medium]: "💇🏽", 
				[.mediumDark]: "💇🏾", 
				[.dark]: "💇🏿"
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
			.flexedBiceps:[
				[.light]: "💪🏻", 
				[.mediumLight]: "💪🏼", 
				[.medium]: "💪🏽", 
				[.mediumDark]: "💪🏾", 
				[.dark]: "💪🏿"
			],
			.personInSuitLevitating:[
				[.light]: "🕴🏻", 
				[.mediumLight]: "🕴🏼", 
				[.medium]: "🕴🏽", 
				[.mediumDark]: "🕴🏾", 
				[.dark]: "🕴🏿"
			],
			.womanDetective:[
				[.light]: "🕵🏻‍♀️", 
				[.mediumLight]: "🕵🏼‍♀️", 
				[.medium]: "🕵🏽‍♀️", 
				[.mediumDark]: "🕵🏾‍♀️", 
				[.dark]: "🕵🏿‍♀️"
			],
			.manDetective:[
				[.light]: "🕵🏻‍♂️", 
				[.mediumLight]: "🕵🏼‍♂️", 
				[.medium]: "🕵🏽‍♂️", 
				[.mediumDark]: "🕵🏾‍♂️", 
				[.dark]: "🕵🏿‍♂️"
			],
			.detective:[
				[.light]: "🕵🏻", 
				[.mediumLight]: "🕵🏼", 
				[.medium]: "🕵🏽", 
				[.mediumDark]: "🕵🏾", 
				[.dark]: "🕵🏿"
			],
			.manDancing:[
				[.light]: "🕺🏻", 
				[.mediumLight]: "🕺🏼", 
				[.medium]: "🕺🏽", 
				[.mediumDark]: "🕺🏾", 
				[.dark]: "🕺🏿"
			],
			.handWithFingersSplayed:[
				[.light]: "🖐🏻", 
				[.mediumLight]: "🖐🏼", 
				[.medium]: "🖐🏽", 
				[.mediumDark]: "🖐🏾", 
				[.dark]: "🖐🏿"
			],
			.reversedHandWithMiddleFingerExtended:[
				[.light]: "🖕🏻", 
				[.mediumLight]: "🖕🏼", 
				[.medium]: "🖕🏽", 
				[.mediumDark]: "🖕🏾", 
				[.dark]: "🖕🏿"
			],
			.raisedHandWithPartBetweenMiddleAndRingFingers:[
				[.light]: "🖖🏻", 
				[.mediumLight]: "🖖🏼", 
				[.medium]: "🖖🏽", 
				[.mediumDark]: "🖖🏾", 
				[.dark]: "🖖🏿"
			],
			.womanGesturingNo:[
				[.light]: "🙅🏻‍♀️", 
				[.mediumLight]: "🙅🏼‍♀️", 
				[.medium]: "🙅🏽‍♀️", 
				[.mediumDark]: "🙅🏾‍♀️", 
				[.dark]: "🙅🏿‍♀️"
			],
			.manGesturingNo:[
				[.light]: "🙅🏻‍♂️", 
				[.mediumLight]: "🙅🏼‍♂️", 
				[.medium]: "🙅🏽‍♂️", 
				[.mediumDark]: "🙅🏾‍♂️", 
				[.dark]: "🙅🏿‍♂️"
			],
			.faceWithNoGoodGesture:[
				[.light]: "🙅🏻", 
				[.mediumLight]: "🙅🏼", 
				[.medium]: "🙅🏽", 
				[.mediumDark]: "🙅🏾", 
				[.dark]: "🙅🏿"
			],
			.womanGesturingOk:[
				[.light]: "🙆🏻‍♀️", 
				[.mediumLight]: "🙆🏼‍♀️", 
				[.medium]: "🙆🏽‍♀️", 
				[.mediumDark]: "🙆🏾‍♀️", 
				[.dark]: "🙆🏿‍♀️"
			],
			.manGesturingOk:[
				[.light]: "🙆🏻‍♂️", 
				[.mediumLight]: "🙆🏼‍♂️", 
				[.medium]: "🙆🏽‍♂️", 
				[.mediumDark]: "🙆🏾‍♂️", 
				[.dark]: "🙆🏿‍♂️"
			],
			.faceWithOkGesture:[
				[.light]: "🙆🏻", 
				[.mediumLight]: "🙆🏼", 
				[.medium]: "🙆🏽", 
				[.mediumDark]: "🙆🏾", 
				[.dark]: "🙆🏿"
			],
			.womanBowing:[
				[.light]: "🙇🏻‍♀️", 
				[.mediumLight]: "🙇🏼‍♀️", 
				[.medium]: "🙇🏽‍♀️", 
				[.mediumDark]: "🙇🏾‍♀️", 
				[.dark]: "🙇🏿‍♀️"
			],
			.manBowing:[
				[.light]: "🙇🏻‍♂️", 
				[.mediumLight]: "🙇🏼‍♂️", 
				[.medium]: "🙇🏽‍♂️", 
				[.mediumDark]: "🙇🏾‍♂️", 
				[.dark]: "🙇🏿‍♂️"
			],
			.personBowingDeeply:[
				[.light]: "🙇🏻", 
				[.mediumLight]: "🙇🏼", 
				[.medium]: "🙇🏽", 
				[.mediumDark]: "🙇🏾", 
				[.dark]: "🙇🏿"
			],
			.womanRaisingHand:[
				[.light]: "🙋🏻‍♀️", 
				[.mediumLight]: "🙋🏼‍♀️", 
				[.medium]: "🙋🏽‍♀️", 
				[.mediumDark]: "🙋🏾‍♀️", 
				[.dark]: "🙋🏿‍♀️"
			],
			.manRaisingHand:[
				[.light]: "🙋🏻‍♂️", 
				[.mediumLight]: "🙋🏼‍♂️", 
				[.medium]: "🙋🏽‍♂️", 
				[.mediumDark]: "🙋🏾‍♂️", 
				[.dark]: "🙋🏿‍♂️"
			],
			.happyPersonRaisingOneHand:[
				[.light]: "🙋🏻", 
				[.mediumLight]: "🙋🏼", 
				[.medium]: "🙋🏽", 
				[.mediumDark]: "🙋🏾", 
				[.dark]: "🙋🏿"
			],
			.personRaisingBothHandsInCelebration:[
				[.light]: "🙌🏻", 
				[.mediumLight]: "🙌🏼", 
				[.medium]: "🙌🏽", 
				[.mediumDark]: "🙌🏾", 
				[.dark]: "🙌🏿"
			],
			.womanFrowning:[
				[.light]: "🙍🏻‍♀️", 
				[.mediumLight]: "🙍🏼‍♀️", 
				[.medium]: "🙍🏽‍♀️", 
				[.mediumDark]: "🙍🏾‍♀️", 
				[.dark]: "🙍🏿‍♀️"
			],
			.manFrowning:[
				[.light]: "🙍🏻‍♂️", 
				[.mediumLight]: "🙍🏼‍♂️", 
				[.medium]: "🙍🏽‍♂️", 
				[.mediumDark]: "🙍🏾‍♂️", 
				[.dark]: "🙍🏿‍♂️"
			],
			.personFrowning:[
				[.light]: "🙍🏻", 
				[.mediumLight]: "🙍🏼", 
				[.medium]: "🙍🏽", 
				[.mediumDark]: "🙍🏾", 
				[.dark]: "🙍🏿"
			],
			.womanPouting:[
				[.light]: "🙎🏻‍♀️", 
				[.mediumLight]: "🙎🏼‍♀️", 
				[.medium]: "🙎🏽‍♀️", 
				[.mediumDark]: "🙎🏾‍♀️", 
				[.dark]: "🙎🏿‍♀️"
			],
			.manPouting:[
				[.light]: "🙎🏻‍♂️", 
				[.mediumLight]: "🙎🏼‍♂️", 
				[.medium]: "🙎🏽‍♂️", 
				[.mediumDark]: "🙎🏾‍♂️", 
				[.dark]: "🙎🏿‍♂️"
			],
			.personWithPoutingFace:[
				[.light]: "🙎🏻", 
				[.mediumLight]: "🙎🏼", 
				[.medium]: "🙎🏽", 
				[.mediumDark]: "🙎🏾", 
				[.dark]: "🙎🏿"
			],
			.personWithFoldedHands:[
				[.light]: "🙏🏻", 
				[.mediumLight]: "🙏🏼", 
				[.medium]: "🙏🏽", 
				[.mediumDark]: "🙏🏾", 
				[.dark]: "🙏🏿"
			],
			.womanRowingBoat:[
				[.light]: "🚣🏻‍♀️", 
				[.mediumLight]: "🚣🏼‍♀️", 
				[.medium]: "🚣🏽‍♀️", 
				[.mediumDark]: "🚣🏾‍♀️", 
				[.dark]: "🚣🏿‍♀️"
			],
			.manRowingBoat:[
				[.light]: "🚣🏻‍♂️", 
				[.mediumLight]: "🚣🏼‍♂️", 
				[.medium]: "🚣🏽‍♂️", 
				[.mediumDark]: "🚣🏾‍♂️", 
				[.dark]: "🚣🏿‍♂️"
			],
			.rowboat:[
				[.light]: "🚣🏻", 
				[.mediumLight]: "🚣🏼", 
				[.medium]: "🚣🏽", 
				[.mediumDark]: "🚣🏾", 
				[.dark]: "🚣🏿"
			],
			.womanBiking:[
				[.light]: "🚴🏻‍♀️", 
				[.mediumLight]: "🚴🏼‍♀️", 
				[.medium]: "🚴🏽‍♀️", 
				[.mediumDark]: "🚴🏾‍♀️", 
				[.dark]: "🚴🏿‍♀️"
			],
			.manBiking:[
				[.light]: "🚴🏻‍♂️", 
				[.mediumLight]: "🚴🏼‍♂️", 
				[.medium]: "🚴🏽‍♂️", 
				[.mediumDark]: "🚴🏾‍♂️", 
				[.dark]: "🚴🏿‍♂️"
			],
			.bicyclist:[
				[.light]: "🚴🏻", 
				[.mediumLight]: "🚴🏼", 
				[.medium]: "🚴🏽", 
				[.mediumDark]: "🚴🏾", 
				[.dark]: "🚴🏿"
			],
			.womanMountainBiking:[
				[.light]: "🚵🏻‍♀️", 
				[.mediumLight]: "🚵🏼‍♀️", 
				[.medium]: "🚵🏽‍♀️", 
				[.mediumDark]: "🚵🏾‍♀️", 
				[.dark]: "🚵🏿‍♀️"
			],
			.manMountainBiking:[
				[.light]: "🚵🏻‍♂️", 
				[.mediumLight]: "🚵🏼‍♂️", 
				[.medium]: "🚵🏽‍♂️", 
				[.mediumDark]: "🚵🏾‍♂️", 
				[.dark]: "🚵🏿‍♂️"
			],
			.mountainBicyclist:[
				[.light]: "🚵🏻", 
				[.mediumLight]: "🚵🏼", 
				[.medium]: "🚵🏽", 
				[.mediumDark]: "🚵🏾", 
				[.dark]: "🚵🏿"
			],
			.womanWalking:[
				[.light]: "🚶🏻‍♀️", 
				[.mediumLight]: "🚶🏼‍♀️", 
				[.medium]: "🚶🏽‍♀️", 
				[.mediumDark]: "🚶🏾‍♀️", 
				[.dark]: "🚶🏿‍♀️"
			],
			.womanWalkingFacingRight:[
				[.light]: "🚶🏻‍♀️‍➡️", 
				[.mediumLight]: "🚶🏼‍♀️‍➡️", 
				[.medium]: "🚶🏽‍♀️‍➡️", 
				[.mediumDark]: "🚶🏾‍♀️‍➡️", 
				[.dark]: "🚶🏿‍♀️‍➡️"
			],
			.manWalking:[
				[.light]: "🚶🏻‍♂️", 
				[.mediumLight]: "🚶🏼‍♂️", 
				[.medium]: "🚶🏽‍♂️", 
				[.mediumDark]: "🚶🏾‍♂️", 
				[.dark]: "🚶🏿‍♂️"
			],
			.manWalkingFacingRight:[
				[.light]: "🚶🏻‍♂️‍➡️", 
				[.mediumLight]: "🚶🏼‍♂️‍➡️", 
				[.medium]: "🚶🏽‍♂️‍➡️", 
				[.mediumDark]: "🚶🏾‍♂️‍➡️", 
				[.dark]: "🚶🏿‍♂️‍➡️"
			],
			.personWalkingFacingRight:[
				[.light]: "🚶🏻‍➡️", 
				[.mediumLight]: "🚶🏼‍➡️", 
				[.medium]: "🚶🏽‍➡️", 
				[.mediumDark]: "🚶🏾‍➡️", 
				[.dark]: "🚶🏿‍➡️"
			],
			.pedestrian:[
				[.light]: "🚶🏻", 
				[.mediumLight]: "🚶🏼", 
				[.medium]: "🚶🏽", 
				[.mediumDark]: "🚶🏾", 
				[.dark]: "🚶🏿"
			],
			.bath:[
				[.light]: "🛀🏻", 
				[.mediumLight]: "🛀🏼", 
				[.medium]: "🛀🏽", 
				[.mediumDark]: "🛀🏾", 
				[.dark]: "🛀🏿"
			],
			.sleepingAccommodation:[
				[.light]: "🛌🏻", 
				[.mediumLight]: "🛌🏼", 
				[.medium]: "🛌🏽", 
				[.mediumDark]: "🛌🏾", 
				[.dark]: "🛌🏿"
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
			.raisedBackOfHand:[
				[.light]: "🤚🏻", 
				[.mediumLight]: "🤚🏼", 
				[.medium]: "🤚🏽", 
				[.mediumDark]: "🤚🏾", 
				[.dark]: "🤚🏿"
			],
			.leftfacingFist:[
				[.light]: "🤛🏻", 
				[.mediumLight]: "🤛🏼", 
				[.medium]: "🤛🏽", 
				[.mediumDark]: "🤛🏾", 
				[.dark]: "🤛🏿"
			],
			.rightfacingFist:[
				[.light]: "🤜🏻", 
				[.mediumLight]: "🤜🏼", 
				[.medium]: "🤜🏽", 
				[.mediumDark]: "🤜🏾", 
				[.dark]: "🤜🏿"
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
			.handWithIndexAndMiddleFingersCrossed:[
				[.light]: "🤞🏻", 
				[.mediumLight]: "🤞🏼", 
				[.medium]: "🤞🏽", 
				[.mediumDark]: "🤞🏾", 
				[.dark]: "🤞🏿"
			],
			.iLoveYouHandSign:[
				[.light]: "🤟🏻", 
				[.mediumLight]: "🤟🏼", 
				[.medium]: "🤟🏽", 
				[.mediumDark]: "🤟🏾", 
				[.dark]: "🤟🏿"
			],
			.womanFacepalming:[
				[.light]: "🤦🏻‍♀️", 
				[.mediumLight]: "🤦🏼‍♀️", 
				[.medium]: "🤦🏽‍♀️", 
				[.mediumDark]: "🤦🏾‍♀️", 
				[.dark]: "🤦🏿‍♀️"
			],
			.manFacepalming:[
				[.light]: "🤦🏻‍♂️", 
				[.mediumLight]: "🤦🏼‍♂️", 
				[.medium]: "🤦🏽‍♂️", 
				[.mediumDark]: "🤦🏾‍♂️", 
				[.dark]: "🤦🏿‍♂️"
			],
			.facePalm:[
				[.light]: "🤦🏻", 
				[.mediumLight]: "🤦🏼", 
				[.medium]: "🤦🏽", 
				[.mediumDark]: "🤦🏾", 
				[.dark]: "🤦🏿"
			],
			.pregnantWoman:[
				[.light]: "🤰🏻", 
				[.mediumLight]: "🤰🏼", 
				[.medium]: "🤰🏽", 
				[.mediumDark]: "🤰🏾", 
				[.dark]: "🤰🏿"
			],
			.breastfeeding:[
				[.light]: "🤱🏻", 
				[.mediumLight]: "🤱🏼", 
				[.medium]: "🤱🏽", 
				[.mediumDark]: "🤱🏾", 
				[.dark]: "🤱🏿"
			],
			.palmsUpTogether:[
				[.light]: "🤲🏻", 
				[.mediumLight]: "🤲🏼", 
				[.medium]: "🤲🏽", 
				[.mediumDark]: "🤲🏾", 
				[.dark]: "🤲🏿"
			],
			.selfie:[
				[.light]: "🤳🏻", 
				[.mediumLight]: "🤳🏼", 
				[.medium]: "🤳🏽", 
				[.mediumDark]: "🤳🏾", 
				[.dark]: "🤳🏿"
			],
			.prince:[
				[.light]: "🤴🏻", 
				[.mediumLight]: "🤴🏼", 
				[.medium]: "🤴🏽", 
				[.mediumDark]: "🤴🏾", 
				[.dark]: "🤴🏿"
			],
			.womanInTuxedo:[
				[.light]: "🤵🏻‍♀️", 
				[.mediumLight]: "🤵🏼‍♀️", 
				[.medium]: "🤵🏽‍♀️", 
				[.mediumDark]: "🤵🏾‍♀️", 
				[.dark]: "🤵🏿‍♀️"
			],
			.manInTuxedo:[
				[.light]: "🤵🏻‍♂️", 
				[.mediumLight]: "🤵🏼‍♂️", 
				[.medium]: "🤵🏽‍♂️", 
				[.mediumDark]: "🤵🏾‍♂️", 
				[.dark]: "🤵🏿‍♂️"
			],
			.motherChristmas:[
				[.light]: "🤶🏻", 
				[.mediumLight]: "🤶🏼", 
				[.medium]: "🤶🏽", 
				[.mediumDark]: "🤶🏾", 
				[.dark]: "🤶🏿"
			],
			.womanShrugging:[
				[.light]: "🤷🏻‍♀️", 
				[.mediumLight]: "🤷🏼‍♀️", 
				[.medium]: "🤷🏽‍♀️", 
				[.mediumDark]: "🤷🏾‍♀️", 
				[.dark]: "🤷🏿‍♀️"
			],
			.manShrugging:[
				[.light]: "🤷🏻‍♂️", 
				[.mediumLight]: "🤷🏼‍♂️", 
				[.medium]: "🤷🏽‍♂️", 
				[.mediumDark]: "🤷🏾‍♂️", 
				[.dark]: "🤷🏿‍♂️"
			],
			.shrug:[
				[.light]: "🤷🏻", 
				[.mediumLight]: "🤷🏼", 
				[.medium]: "🤷🏽", 
				[.mediumDark]: "🤷🏾", 
				[.dark]: "🤷🏿"
			],
			.womanCartwheeling:[
				[.light]: "🤸🏻‍♀️", 
				[.mediumLight]: "🤸🏼‍♀️", 
				[.medium]: "🤸🏽‍♀️", 
				[.mediumDark]: "🤸🏾‍♀️", 
				[.dark]: "🤸🏿‍♀️"
			],
			.manCartwheeling:[
				[.light]: "🤸🏻‍♂️", 
				[.mediumLight]: "🤸🏼‍♂️", 
				[.medium]: "🤸🏽‍♂️", 
				[.mediumDark]: "🤸🏾‍♂️", 
				[.dark]: "🤸🏿‍♂️"
			],
			.personDoingCartwheel:[
				[.light]: "🤸🏻", 
				[.mediumLight]: "🤸🏼", 
				[.medium]: "🤸🏽", 
				[.mediumDark]: "🤸🏾", 
				[.dark]: "🤸🏿"
			],
			.womanJuggling:[
				[.light]: "🤹🏻‍♀️", 
				[.mediumLight]: "🤹🏼‍♀️", 
				[.medium]: "🤹🏽‍♀️", 
				[.mediumDark]: "🤹🏾‍♀️", 
				[.dark]: "🤹🏿‍♀️"
			],
			.manJuggling:[
				[.light]: "🤹🏻‍♂️", 
				[.mediumLight]: "🤹🏼‍♂️", 
				[.medium]: "🤹🏽‍♂️", 
				[.mediumDark]: "🤹🏾‍♂️", 
				[.dark]: "🤹🏿‍♂️"
			],
			.juggling:[
				[.light]: "🤹🏻", 
				[.mediumLight]: "🤹🏼", 
				[.medium]: "🤹🏽", 
				[.mediumDark]: "🤹🏾", 
				[.dark]: "🤹🏿"
			],
			.womanPlayingWaterPolo:[
				[.light]: "🤽🏻‍♀️", 
				[.mediumLight]: "🤽🏼‍♀️", 
				[.medium]: "🤽🏽‍♀️", 
				[.mediumDark]: "🤽🏾‍♀️", 
				[.dark]: "🤽🏿‍♀️"
			],
			.manPlayingWaterPolo:[
				[.light]: "🤽🏻‍♂️", 
				[.mediumLight]: "🤽🏼‍♂️", 
				[.medium]: "🤽🏽‍♂️", 
				[.mediumDark]: "🤽🏾‍♂️", 
				[.dark]: "🤽🏿‍♂️"
			],
			.waterPolo:[
				[.light]: "🤽🏻", 
				[.mediumLight]: "🤽🏼", 
				[.medium]: "🤽🏽", 
				[.mediumDark]: "🤽🏾", 
				[.dark]: "🤽🏿"
			],
			.womanPlayingHandball:[
				[.light]: "🤾🏻‍♀️", 
				[.mediumLight]: "🤾🏼‍♀️", 
				[.medium]: "🤾🏽‍♀️", 
				[.mediumDark]: "🤾🏾‍♀️", 
				[.dark]: "🤾🏿‍♀️"
			],
			.manPlayingHandball:[
				[.light]: "🤾🏻‍♂️", 
				[.mediumLight]: "🤾🏼‍♂️", 
				[.medium]: "🤾🏽‍♂️", 
				[.mediumDark]: "🤾🏾‍♂️", 
				[.dark]: "🤾🏿‍♂️"
			],
			.handball:[
				[.light]: "🤾🏻", 
				[.mediumLight]: "🤾🏼", 
				[.medium]: "🤾🏽", 
				[.mediumDark]: "🤾🏾", 
				[.dark]: "🤾🏿"
			],
			.ninja:[
				[.light]: "🥷🏻", 
				[.mediumLight]: "🥷🏼", 
				[.medium]: "🥷🏽", 
				[.mediumDark]: "🥷🏾", 
				[.dark]: "🥷🏿"
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
			.womanSuperhero:[
				[.light]: "🦸🏻‍♀️", 
				[.mediumLight]: "🦸🏼‍♀️", 
				[.medium]: "🦸🏽‍♀️", 
				[.mediumDark]: "🦸🏾‍♀️", 
				[.dark]: "🦸🏿‍♀️"
			],
			.manSuperhero:[
				[.light]: "🦸🏻‍♂️", 
				[.mediumLight]: "🦸🏼‍♂️", 
				[.medium]: "🦸🏽‍♂️", 
				[.mediumDark]: "🦸🏾‍♂️", 
				[.dark]: "🦸🏿‍♂️"
			],
			.superhero:[
				[.light]: "🦸🏻", 
				[.mediumLight]: "🦸🏼", 
				[.medium]: "🦸🏽", 
				[.mediumDark]: "🦸🏾", 
				[.dark]: "🦸🏿"
			],
			.womanSupervillain:[
				[.light]: "🦹🏻‍♀️", 
				[.mediumLight]: "🦹🏼‍♀️", 
				[.medium]: "🦹🏽‍♀️", 
				[.mediumDark]: "🦹🏾‍♀️", 
				[.dark]: "🦹🏿‍♀️"
			],
			.manSupervillain:[
				[.light]: "🦹🏻‍♂️", 
				[.mediumLight]: "🦹🏼‍♂️", 
				[.medium]: "🦹🏽‍♂️", 
				[.mediumDark]: "🦹🏾‍♂️", 
				[.dark]: "🦹🏿‍♂️"
			],
			.supervillain:[
				[.light]: "🦹🏻", 
				[.mediumLight]: "🦹🏼", 
				[.medium]: "🦹🏽", 
				[.mediumDark]: "🦹🏾", 
				[.dark]: "🦹🏿"
			],
			.earWithHearingAid:[
				[.light]: "🦻🏻", 
				[.mediumLight]: "🦻🏼", 
				[.medium]: "🦻🏽", 
				[.mediumDark]: "🦻🏾", 
				[.dark]: "🦻🏿"
			],
			.womanStanding:[
				[.light]: "🧍🏻‍♀️", 
				[.mediumLight]: "🧍🏼‍♀️", 
				[.medium]: "🧍🏽‍♀️", 
				[.mediumDark]: "🧍🏾‍♀️", 
				[.dark]: "🧍🏿‍♀️"
			],
			.manStanding:[
				[.light]: "🧍🏻‍♂️", 
				[.mediumLight]: "🧍🏼‍♂️", 
				[.medium]: "🧍🏽‍♂️", 
				[.mediumDark]: "🧍🏾‍♂️", 
				[.dark]: "🧍🏿‍♂️"
			],
			.standingPerson:[
				[.light]: "🧍🏻", 
				[.mediumLight]: "🧍🏼", 
				[.medium]: "🧍🏽", 
				[.mediumDark]: "🧍🏾", 
				[.dark]: "🧍🏿"
			],
			.womanKneeling:[
				[.light]: "🧎🏻‍♀️", 
				[.mediumLight]: "🧎🏼‍♀️", 
				[.medium]: "🧎🏽‍♀️", 
				[.mediumDark]: "🧎🏾‍♀️", 
				[.dark]: "🧎🏿‍♀️"
			],
			.womanKneelingFacingRight:[
				[.light]: "🧎🏻‍♀️‍➡️", 
				[.mediumLight]: "🧎🏼‍♀️‍➡️", 
				[.medium]: "🧎🏽‍♀️‍➡️", 
				[.mediumDark]: "🧎🏾‍♀️‍➡️", 
				[.dark]: "🧎🏿‍♀️‍➡️"
			],
			.manKneeling:[
				[.light]: "🧎🏻‍♂️", 
				[.mediumLight]: "🧎🏼‍♂️", 
				[.medium]: "🧎🏽‍♂️", 
				[.mediumDark]: "🧎🏾‍♂️", 
				[.dark]: "🧎🏿‍♂️"
			],
			.manKneelingFacingRight:[
				[.light]: "🧎🏻‍♂️‍➡️", 
				[.mediumLight]: "🧎🏼‍♂️‍➡️", 
				[.medium]: "🧎🏽‍♂️‍➡️", 
				[.mediumDark]: "🧎🏾‍♂️‍➡️", 
				[.dark]: "🧎🏿‍♂️‍➡️"
			],
			.personKneelingFacingRight:[
				[.light]: "🧎🏻‍➡️", 
				[.mediumLight]: "🧎🏼‍➡️", 
				[.medium]: "🧎🏽‍➡️", 
				[.mediumDark]: "🧎🏾‍➡️", 
				[.dark]: "🧎🏿‍➡️"
			],
			.kneelingPerson:[
				[.light]: "🧎🏻", 
				[.mediumLight]: "🧎🏼", 
				[.medium]: "🧎🏽", 
				[.mediumDark]: "🧎🏾", 
				[.dark]: "🧎🏿"
			],
			.deafWoman:[
				[.light]: "🧏🏻‍♀️", 
				[.mediumLight]: "🧏🏼‍♀️", 
				[.medium]: "🧏🏽‍♀️", 
				[.mediumDark]: "🧏🏾‍♀️", 
				[.dark]: "🧏🏿‍♀️"
			],
			.deafMan:[
				[.light]: "🧏🏻‍♂️", 
				[.mediumLight]: "🧏🏼‍♂️", 
				[.medium]: "🧏🏽‍♂️", 
				[.mediumDark]: "🧏🏾‍♂️", 
				[.dark]: "🧏🏿‍♂️"
			],
			.deafPerson:[
				[.light]: "🧏🏻", 
				[.mediumLight]: "🧏🏼", 
				[.medium]: "🧏🏽", 
				[.mediumDark]: "🧏🏾", 
				[.dark]: "🧏🏿"
			],
			.farmer:[
				[.light]: "🧑🏻‍🌾", 
				[.mediumLight]: "🧑🏼‍🌾", 
				[.medium]: "🧑🏽‍🌾", 
				[.mediumDark]: "🧑🏾‍🌾", 
				[.dark]: "🧑🏿‍🌾"
			],
			.cook:[
				[.light]: "🧑🏻‍🍳", 
				[.mediumLight]: "🧑🏼‍🍳", 
				[.medium]: "🧑🏽‍🍳", 
				[.mediumDark]: "🧑🏾‍🍳", 
				[.dark]: "🧑🏿‍🍳"
			],
			.personFeedingBaby:[
				[.light]: "🧑🏻‍🍼", 
				[.mediumLight]: "🧑🏼‍🍼", 
				[.medium]: "🧑🏽‍🍼", 
				[.mediumDark]: "🧑🏾‍🍼", 
				[.dark]: "🧑🏿‍🍼"
			],
			.mxClaus:[
				[.light]: "🧑🏻‍🎄", 
				[.mediumLight]: "🧑🏼‍🎄", 
				[.medium]: "🧑🏽‍🎄", 
				[.mediumDark]: "🧑🏾‍🎄", 
				[.dark]: "🧑🏿‍🎄"
			],
			.student:[
				[.light]: "🧑🏻‍🎓", 
				[.mediumLight]: "🧑🏼‍🎓", 
				[.medium]: "🧑🏽‍🎓", 
				[.mediumDark]: "🧑🏾‍🎓", 
				[.dark]: "🧑🏿‍🎓"
			],
			.singer:[
				[.light]: "🧑🏻‍🎤", 
				[.mediumLight]: "🧑🏼‍🎤", 
				[.medium]: "🧑🏽‍🎤", 
				[.mediumDark]: "🧑🏾‍🎤", 
				[.dark]: "🧑🏿‍🎤"
			],
			.artist:[
				[.light]: "🧑🏻‍🎨", 
				[.mediumLight]: "🧑🏼‍🎨", 
				[.medium]: "🧑🏽‍🎨", 
				[.mediumDark]: "🧑🏾‍🎨", 
				[.dark]: "🧑🏿‍🎨"
			],
			.teacher:[
				[.light]: "🧑🏻‍🏫", 
				[.mediumLight]: "🧑🏼‍🏫", 
				[.medium]: "🧑🏽‍🏫", 
				[.mediumDark]: "🧑🏾‍🏫", 
				[.dark]: "🧑🏿‍🏫"
			],
			.factoryWorker:[
				[.light]: "🧑🏻‍🏭", 
				[.mediumLight]: "🧑🏼‍🏭", 
				[.medium]: "🧑🏽‍🏭", 
				[.mediumDark]: "🧑🏾‍🏭", 
				[.dark]: "🧑🏿‍🏭"
			],
			.technologist:[
				[.light]: "🧑🏻‍💻", 
				[.mediumLight]: "🧑🏼‍💻", 
				[.medium]: "🧑🏽‍💻", 
				[.mediumDark]: "🧑🏾‍💻", 
				[.dark]: "🧑🏿‍💻"
			],
			.officeWorker:[
				[.light]: "🧑🏻‍💼", 
				[.mediumLight]: "🧑🏼‍💼", 
				[.medium]: "🧑🏽‍💼", 
				[.mediumDark]: "🧑🏾‍💼", 
				[.dark]: "🧑🏿‍💼"
			],
			.mechanic:[
				[.light]: "🧑🏻‍🔧", 
				[.mediumLight]: "🧑🏼‍🔧", 
				[.medium]: "🧑🏽‍🔧", 
				[.mediumDark]: "🧑🏾‍🔧", 
				[.dark]: "🧑🏿‍🔧"
			],
			.scientist:[
				[.light]: "🧑🏻‍🔬", 
				[.mediumLight]: "🧑🏼‍🔬", 
				[.medium]: "🧑🏽‍🔬", 
				[.mediumDark]: "🧑🏾‍🔬", 
				[.dark]: "🧑🏿‍🔬"
			],
			.astronaut:[
				[.light]: "🧑🏻‍🚀", 
				[.mediumLight]: "🧑🏼‍🚀", 
				[.medium]: "🧑🏽‍🚀", 
				[.mediumDark]: "🧑🏾‍🚀", 
				[.dark]: "🧑🏿‍🚀"
			],
			.firefighter:[
				[.light]: "🧑🏻‍🚒", 
				[.mediumLight]: "🧑🏼‍🚒", 
				[.medium]: "🧑🏽‍🚒", 
				[.mediumDark]: "🧑🏾‍🚒", 
				[.dark]: "🧑🏿‍🚒"
			],
			.peopleHoldingHands:[
				[.light, .light]: "🧑🏻‍🤝‍🧑🏻", 
				[.light, .mediumLight]: "🧑🏻‍🤝‍🧑🏼", 
				[.light, .medium]: "🧑🏻‍🤝‍🧑🏽", 
				[.light, .mediumDark]: "🧑🏻‍🤝‍🧑🏾", 
				[.light, .dark]: "🧑🏻‍🤝‍🧑🏿", 
				[.mediumLight, .light]: "🧑🏼‍🤝‍🧑🏻", 
				[.mediumLight, .mediumLight]: "🧑🏼‍🤝‍🧑🏼", 
				[.mediumLight, .medium]: "🧑🏼‍🤝‍🧑🏽", 
				[.mediumLight, .mediumDark]: "🧑🏼‍🤝‍🧑🏾", 
				[.mediumLight, .dark]: "🧑🏼‍🤝‍🧑🏿", 
				[.medium, .light]: "🧑🏽‍🤝‍🧑🏻", 
				[.medium, .mediumLight]: "🧑🏽‍🤝‍🧑🏼", 
				[.medium, .medium]: "🧑🏽‍🤝‍🧑🏽", 
				[.medium, .mediumDark]: "🧑🏽‍🤝‍🧑🏾", 
				[.medium, .dark]: "🧑🏽‍🤝‍🧑🏿", 
				[.mediumDark, .light]: "🧑🏾‍🤝‍🧑🏻", 
				[.mediumDark, .mediumLight]: "🧑🏾‍🤝‍🧑🏼", 
				[.mediumDark, .medium]: "🧑🏾‍🤝‍🧑🏽", 
				[.mediumDark, .mediumDark]: "🧑🏾‍🤝‍🧑🏾", 
				[.mediumDark, .dark]: "🧑🏾‍🤝‍🧑🏿", 
				[.dark, .light]: "🧑🏿‍🤝‍🧑🏻", 
				[.dark, .mediumLight]: "🧑🏿‍🤝‍🧑🏼", 
				[.dark, .medium]: "🧑🏿‍🤝‍🧑🏽", 
				[.dark, .mediumDark]: "🧑🏿‍🤝‍🧑🏾", 
				[.dark, .dark]: "🧑🏿‍🤝‍🧑🏿"
			],
			.personWithWhiteCaneFacingRight:[
				[.light]: "🧑🏻‍🦯‍➡️", 
				[.mediumLight]: "🧑🏼‍🦯‍➡️", 
				[.medium]: "🧑🏽‍🦯‍➡️", 
				[.mediumDark]: "🧑🏾‍🦯‍➡️", 
				[.dark]: "🧑🏿‍🦯‍➡️"
			],
			.personWithWhiteCane:[
				[.light]: "🧑🏻‍🦯", 
				[.mediumLight]: "🧑🏼‍🦯", 
				[.medium]: "🧑🏽‍🦯", 
				[.mediumDark]: "🧑🏾‍🦯", 
				[.dark]: "🧑🏿‍🦯"
			],
			.personRedHair:[
				[.light]: "🧑🏻‍🦰", 
				[.mediumLight]: "🧑🏼‍🦰", 
				[.medium]: "🧑🏽‍🦰", 
				[.mediumDark]: "🧑🏾‍🦰", 
				[.dark]: "🧑🏿‍🦰"
			],
			.personCurlyHair:[
				[.light]: "🧑🏻‍🦱", 
				[.mediumLight]: "🧑🏼‍🦱", 
				[.medium]: "🧑🏽‍🦱", 
				[.mediumDark]: "🧑🏾‍🦱", 
				[.dark]: "🧑🏿‍🦱"
			],
			.personBald:[
				[.light]: "🧑🏻‍🦲", 
				[.mediumLight]: "🧑🏼‍🦲", 
				[.medium]: "🧑🏽‍🦲", 
				[.mediumDark]: "🧑🏾‍🦲", 
				[.dark]: "🧑🏿‍🦲"
			],
			.personWhiteHair:[
				[.light]: "🧑🏻‍🦳", 
				[.mediumLight]: "🧑🏼‍🦳", 
				[.medium]: "🧑🏽‍🦳", 
				[.mediumDark]: "🧑🏾‍🦳", 
				[.dark]: "🧑🏿‍🦳"
			],
			.personInMotorizedWheelchairFacingRight:[
				[.light]: "🧑🏻‍🦼‍➡️", 
				[.mediumLight]: "🧑🏼‍🦼‍➡️", 
				[.medium]: "🧑🏽‍🦼‍➡️", 
				[.mediumDark]: "🧑🏾‍🦼‍➡️", 
				[.dark]: "🧑🏿‍🦼‍➡️"
			],
			.personInMotorizedWheelchair:[
				[.light]: "🧑🏻‍🦼", 
				[.mediumLight]: "🧑🏼‍🦼", 
				[.medium]: "🧑🏽‍🦼", 
				[.mediumDark]: "🧑🏾‍🦼", 
				[.dark]: "🧑🏿‍🦼"
			],
			.personInManualWheelchairFacingRight:[
				[.light]: "🧑🏻‍🦽‍➡️", 
				[.mediumLight]: "🧑🏼‍🦽‍➡️", 
				[.medium]: "🧑🏽‍🦽‍➡️", 
				[.mediumDark]: "🧑🏾‍🦽‍➡️", 
				[.dark]: "🧑🏿‍🦽‍➡️"
			],
			.personInManualWheelchair:[
				[.light]: "🧑🏻‍🦽", 
				[.mediumLight]: "🧑🏼‍🦽", 
				[.medium]: "🧑🏽‍🦽", 
				[.mediumDark]: "🧑🏾‍🦽", 
				[.dark]: "🧑🏿‍🦽"
			],
			.healthWorker:[
				[.light]: "🧑🏻‍⚕️", 
				[.mediumLight]: "🧑🏼‍⚕️", 
				[.medium]: "🧑🏽‍⚕️", 
				[.mediumDark]: "🧑🏾‍⚕️", 
				[.dark]: "🧑🏿‍⚕️"
			],
			.judge:[
				[.light]: "🧑🏻‍⚖️", 
				[.mediumLight]: "🧑🏼‍⚖️", 
				[.medium]: "🧑🏽‍⚖️", 
				[.mediumDark]: "🧑🏾‍⚖️", 
				[.dark]: "🧑🏿‍⚖️"
			],
			.pilot:[
				[.light]: "🧑🏻‍✈️", 
				[.mediumLight]: "🧑🏼‍✈️", 
				[.medium]: "🧑🏽‍✈️", 
				[.mediumDark]: "🧑🏾‍✈️", 
				[.dark]: "🧑🏿‍✈️"
			],
			.adult:[
				[.light]: "🧑🏻", 
				[.mediumLight]: "🧑🏼", 
				[.medium]: "🧑🏽", 
				[.mediumDark]: "🧑🏾", 
				[.dark]: "🧑🏿"
			],
			.child:[
				[.light]: "🧒🏻", 
				[.mediumLight]: "🧒🏼", 
				[.medium]: "🧒🏽", 
				[.mediumDark]: "🧒🏾", 
				[.dark]: "🧒🏿"
			],
			.olderAdult:[
				[.light]: "🧓🏻", 
				[.mediumLight]: "🧓🏼", 
				[.medium]: "🧓🏽", 
				[.mediumDark]: "🧓🏾", 
				[.dark]: "🧓🏿"
			],
			.womanBeard:[
				[.light]: "🧔🏻‍♀️", 
				[.mediumLight]: "🧔🏼‍♀️", 
				[.medium]: "🧔🏽‍♀️", 
				[.mediumDark]: "🧔🏾‍♀️", 
				[.dark]: "🧔🏿‍♀️"
			],
			.manBeard:[
				[.light]: "🧔🏻‍♂️", 
				[.mediumLight]: "🧔🏼‍♂️", 
				[.medium]: "🧔🏽‍♂️", 
				[.mediumDark]: "🧔🏾‍♂️", 
				[.dark]: "🧔🏿‍♂️"
			],
			.beardedPerson:[
				[.light]: "🧔🏻", 
				[.mediumLight]: "🧔🏼", 
				[.medium]: "🧔🏽", 
				[.mediumDark]: "🧔🏾", 
				[.dark]: "🧔🏿"
			],
			.personWithHeadscarf:[
				[.light]: "🧕🏻", 
				[.mediumLight]: "🧕🏼", 
				[.medium]: "🧕🏽", 
				[.mediumDark]: "🧕🏾", 
				[.dark]: "🧕🏿"
			],
			.womanInSteamyRoom:[
				[.light]: "🧖🏻‍♀️", 
				[.mediumLight]: "🧖🏼‍♀️", 
				[.medium]: "🧖🏽‍♀️", 
				[.mediumDark]: "🧖🏾‍♀️", 
				[.dark]: "🧖🏿‍♀️"
			],
			.manInSteamyRoom:[
				[.light]: "🧖🏻‍♂️", 
				[.mediumLight]: "🧖🏼‍♂️", 
				[.medium]: "🧖🏽‍♂️", 
				[.mediumDark]: "🧖🏾‍♂️", 
				[.dark]: "🧖🏿‍♂️"
			],
			.personInSteamyRoom:[
				[.light]: "🧖🏻", 
				[.mediumLight]: "🧖🏼", 
				[.medium]: "🧖🏽", 
				[.mediumDark]: "🧖🏾", 
				[.dark]: "🧖🏿"
			],
			.womanClimbing:[
				[.light]: "🧗🏻‍♀️", 
				[.mediumLight]: "🧗🏼‍♀️", 
				[.medium]: "🧗🏽‍♀️", 
				[.mediumDark]: "🧗🏾‍♀️", 
				[.dark]: "🧗🏿‍♀️"
			],
			.manClimbing:[
				[.light]: "🧗🏻‍♂️", 
				[.mediumLight]: "🧗🏼‍♂️", 
				[.medium]: "🧗🏽‍♂️", 
				[.mediumDark]: "🧗🏾‍♂️", 
				[.dark]: "🧗🏿‍♂️"
			],
			.personClimbing:[
				[.light]: "🧗🏻", 
				[.mediumLight]: "🧗🏼", 
				[.medium]: "🧗🏽", 
				[.mediumDark]: "🧗🏾", 
				[.dark]: "🧗🏿"
			],
			.womanInLotusPosition:[
				[.light]: "🧘🏻‍♀️", 
				[.mediumLight]: "🧘🏼‍♀️", 
				[.medium]: "🧘🏽‍♀️", 
				[.mediumDark]: "🧘🏾‍♀️", 
				[.dark]: "🧘🏿‍♀️"
			],
			.manInLotusPosition:[
				[.light]: "🧘🏻‍♂️", 
				[.mediumLight]: "🧘🏼‍♂️", 
				[.medium]: "🧘🏽‍♂️", 
				[.mediumDark]: "🧘🏾‍♂️", 
				[.dark]: "🧘🏿‍♂️"
			],
			.personInLotusPosition:[
				[.light]: "🧘🏻", 
				[.mediumLight]: "🧘🏼", 
				[.medium]: "🧘🏽", 
				[.mediumDark]: "🧘🏾", 
				[.dark]: "🧘🏿"
			],
			.womanMage:[
				[.light]: "🧙🏻‍♀️", 
				[.mediumLight]: "🧙🏼‍♀️", 
				[.medium]: "🧙🏽‍♀️", 
				[.mediumDark]: "🧙🏾‍♀️", 
				[.dark]: "🧙🏿‍♀️"
			],
			.manMage:[
				[.light]: "🧙🏻‍♂️", 
				[.mediumLight]: "🧙🏼‍♂️", 
				[.medium]: "🧙🏽‍♂️", 
				[.mediumDark]: "🧙🏾‍♂️", 
				[.dark]: "🧙🏿‍♂️"
			],
			.mage:[
				[.light]: "🧙🏻", 
				[.mediumLight]: "🧙🏼", 
				[.medium]: "🧙🏽", 
				[.mediumDark]: "🧙🏾", 
				[.dark]: "🧙🏿"
			],
			.womanFairy:[
				[.light]: "🧚🏻‍♀️", 
				[.mediumLight]: "🧚🏼‍♀️", 
				[.medium]: "🧚🏽‍♀️", 
				[.mediumDark]: "🧚🏾‍♀️", 
				[.dark]: "🧚🏿‍♀️"
			],
			.manFairy:[
				[.light]: "🧚🏻‍♂️", 
				[.mediumLight]: "🧚🏼‍♂️", 
				[.medium]: "🧚🏽‍♂️", 
				[.mediumDark]: "🧚🏾‍♂️", 
				[.dark]: "🧚🏿‍♂️"
			],
			.fairy:[
				[.light]: "🧚🏻", 
				[.mediumLight]: "🧚🏼", 
				[.medium]: "🧚🏽", 
				[.mediumDark]: "🧚🏾", 
				[.dark]: "🧚🏿"
			],
			.womanVampire:[
				[.light]: "🧛🏻‍♀️", 
				[.mediumLight]: "🧛🏼‍♀️", 
				[.medium]: "🧛🏽‍♀️", 
				[.mediumDark]: "🧛🏾‍♀️", 
				[.dark]: "🧛🏿‍♀️"
			],
			.manVampire:[
				[.light]: "🧛🏻‍♂️", 
				[.mediumLight]: "🧛🏼‍♂️", 
				[.medium]: "🧛🏽‍♂️", 
				[.mediumDark]: "🧛🏾‍♂️", 
				[.dark]: "🧛🏿‍♂️"
			],
			.vampire:[
				[.light]: "🧛🏻", 
				[.mediumLight]: "🧛🏼", 
				[.medium]: "🧛🏽", 
				[.mediumDark]: "🧛🏾", 
				[.dark]: "🧛🏿"
			],
			.mermaid:[
				[.light]: "🧜🏻‍♀️", 
				[.mediumLight]: "🧜🏼‍♀️", 
				[.medium]: "🧜🏽‍♀️", 
				[.mediumDark]: "🧜🏾‍♀️", 
				[.dark]: "🧜🏿‍♀️"
			],
			.merman:[
				[.light]: "🧜🏻‍♂️", 
				[.mediumLight]: "🧜🏼‍♂️", 
				[.medium]: "🧜🏽‍♂️", 
				[.mediumDark]: "🧜🏾‍♂️", 
				[.dark]: "🧜🏿‍♂️"
			],
			.merperson:[
				[.light]: "🧜🏻", 
				[.mediumLight]: "🧜🏼", 
				[.medium]: "🧜🏽", 
				[.mediumDark]: "🧜🏾", 
				[.dark]: "🧜🏿"
			],
			.womanElf:[
				[.light]: "🧝🏻‍♀️", 
				[.mediumLight]: "🧝🏼‍♀️", 
				[.medium]: "🧝🏽‍♀️", 
				[.mediumDark]: "🧝🏾‍♀️", 
				[.dark]: "🧝🏿‍♀️"
			],
			.manElf:[
				[.light]: "🧝🏻‍♂️", 
				[.mediumLight]: "🧝🏼‍♂️", 
				[.medium]: "🧝🏽‍♂️", 
				[.mediumDark]: "🧝🏾‍♂️", 
				[.dark]: "🧝🏿‍♂️"
			],
			.elf:[
				[.light]: "🧝🏻", 
				[.mediumLight]: "🧝🏼", 
				[.medium]: "🧝🏽", 
				[.mediumDark]: "🧝🏾", 
				[.dark]: "🧝🏿"
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
			.personWithCrown:[
				[.light]: "🫅🏻", 
				[.mediumLight]: "🫅🏼", 
				[.medium]: "🫅🏽", 
				[.mediumDark]: "🫅🏾", 
				[.dark]: "🫅🏿"
			],
			.handWithIndexFingerAndThumbCrossed:[
				[.light]: "🫰🏻", 
				[.mediumLight]: "🫰🏼", 
				[.medium]: "🫰🏽", 
				[.mediumDark]: "🫰🏾", 
				[.dark]: "🫰🏿"
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
			.indexPointingAtTheViewer:[
				[.light]: "🫵🏻", 
				[.mediumLight]: "🫵🏼", 
				[.medium]: "🫵🏽", 
				[.mediumDark]: "🫵🏾", 
				[.dark]: "🫵🏿"
			],
			.heartHands:[
				[.light]: "🫶🏻", 
				[.mediumLight]: "🫶🏼", 
				[.medium]: "🫶🏽", 
				[.mediumDark]: "🫶🏾", 
				[.dark]: "🫶🏿"
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
			.whiteUpPointingIndex:[
				[.light]: "☝🏻", 
				[.mediumLight]: "☝🏼", 
				[.medium]: "☝🏽", 
				[.mediumDark]: "☝🏾", 
				[.dark]: "☝🏿"
			],
			.womanBouncingBall:[
				[.light]: "⛹🏻‍♀️", 
				[.mediumLight]: "⛹🏼‍♀️", 
				[.medium]: "⛹🏽‍♀️", 
				[.mediumDark]: "⛹🏾‍♀️", 
				[.dark]: "⛹🏿‍♀️"
			],
			.manBouncingBall:[
				[.light]: "⛹🏻‍♂️", 
				[.mediumLight]: "⛹🏼‍♂️", 
				[.medium]: "⛹🏽‍♂️", 
				[.mediumDark]: "⛹🏾‍♂️", 
				[.dark]: "⛹🏿‍♂️"
			],
			.personBouncingBall:[
				[.light]: "⛹🏻", 
				[.mediumLight]: "⛹🏼", 
				[.medium]: "⛹🏽", 
				[.mediumDark]: "⛹🏾", 
				[.dark]: "⛹🏿"
			],
			.raisedFist:[
				[.light]: "✊🏻", 
				[.mediumLight]: "✊🏼", 
				[.medium]: "✊🏽", 
				[.mediumDark]: "✊🏾", 
				[.dark]: "✊🏿"
			],
			.raisedHand:[
				[.light]: "✋🏻", 
				[.mediumLight]: "✋🏼", 
				[.medium]: "✋🏽", 
				[.mediumDark]: "✋🏾", 
				[.dark]: "✋🏿"
			],
			.victoryHand:[
				[.light]: "✌🏻", 
				[.mediumLight]: "✌🏼", 
				[.medium]: "✌🏽", 
				[.mediumDark]: "✌🏾", 
				[.dark]: "✌🏿"
			],
			.writingHand:[
				[.light]: "✍🏻", 
				[.mediumLight]: "✍🏼", 
				[.medium]: "✍🏽", 
				[.mediumDark]: "✍🏾", 
				[.dark]: "✍🏿"
			],
        ]
    }()
    
    public var variants: [[SkinTone]: String]? {
        Emoji.allVariants[self]
    }
}
