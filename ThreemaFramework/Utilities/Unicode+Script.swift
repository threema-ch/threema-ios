//  _____ _
// |_   _| |_  _ _ ___ ___ _ __  __ _
//   | | | ' \| '_/ -_) -_) '  \/ _` |_
//   |_| |_||_|_| \___\___|_|_|_\__,_(_)
//
// Threema iOS Client
// Copyright (c) 2024 Threema GmbH
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

extension Unicode {
    
    /// All Unicode Script types
    public enum ThreemaScript {
        case common,
             latin,
             greek,
             cyrillic,
             armenian,
             hebrew,
             arabic,
             syriac,
             thaana,
             devanagari,
             bengali,
             gurmukhi,
             gujarati,
             oriya,
             tamil,
             telugu,
             kannada,
             malayalam,
             sinhala,
             thai,
             lao,
             tibetan,
             myanmar,
             georgian,
             hangul,
             ethiopic,
             cherokee,
             canadianAboriginal,
             ogham,
             runic,
             khmer,
             mongolian,
             hiragana,
             katakana,
             bopomofo,
             han,
             yi,
             oldItalic,
             gothic,
             deseret,
             inherited,
             tagalog,
             hanunoo,
             buhid,
             tagbanwa,
             limbu,
             taiLe,
             linearB,
             ugaritic,
             shavian,
             osmanya,
             cypriot,
             braille,
             buginese,
             coptic,
             newTaiLue,
             glagolitic,
             tifinagh,
             sylotiNagri,
             oldPersian,
             kharoshthi,
             balinese,
             cuneiform,
             phoenician,
             phagsPa,
             nko,
             sundanese,
             batak,
             lepcha,
             olChiki,
             vai,
             saurashtra,
             kayahLi,
             rejang,
             lycian,
             carian,
             lydian,
             cham,
             taiTham,
             taiViet,
             avestan,
             egyptianHieroglyphs,
             samaritan,
             mandaic,
             lisu,
             bamum,
             javanese,
             meeteiMayek,
             imperialAramaic,
             oldSouthArabian,
             inscriptionalParthian,
             inscriptionalPahlavi,
             oldTurkic,
             brahmi,
             kaithi,
             meroiticHieroglyphs,
             meroiticCursive,
             soraSompeng,
             chakma,
             sharada,
             takri,
             miao,
             unknown
    }
    
    /// Sets that may be mixed in URLS without creating a IDNA warning
    public static let validURLUnicodeScriptSets: [Set<Unicode.ThreemaScript>] =
        [
            [
                Unicode.ThreemaScript.latin,
                Unicode.ThreemaScript.han,
                Unicode.ThreemaScript.hiragana,
                Unicode.ThreemaScript.katakana,
            ],
        
            [
                Unicode.ThreemaScript.latin,
                Unicode.ThreemaScript.han,
                Unicode.ThreemaScript.bopomofo,
            ],
        
            [
                Unicode.ThreemaScript.latin,
                Unicode.ThreemaScript.han,
                Unicode.ThreemaScript.hangul,
            ],
        ]
    
    /// Finds the Unicode script for a given code
    /// - Parameter code: Code to retrieve script
    /// - Returns: `Unicode.Script`
    public static func script(for code: UInt32) -> ThreemaScript {
        switch code {
        case ..<0x0041:
            .common
        case ..<0x005B:
            .latin
        case ..<0x0061:
            .common
        case ..<0x007B:
            .latin
        case ..<0x00AA:
            .common
        case ..<0x00AB:
            .latin
        case ..<0x00BA:
            .common
        case ..<0x00BB:
            .latin
        case ..<0x00C0:
            .common
        case ..<0x00D7:
            .latin
        case ..<0x00D8:
            .common
        case ..<0x00F7:
            .latin
        case ..<0x00F8:
            .common
        case ..<0x02B9:
            .latin
        case ..<0x02E0:
            .common
        case ..<0x02E5:
            .latin
        case ..<0x02EA:
            .common
        case ..<0x02EC:
            .bopomofo
        case ..<0x0300:
            .common
        case ..<0x0370:
            .inherited
        case ..<0x0374:
            .greek
        case ..<0x0375:
            .common
        case ..<0x037E:
            .greek
        case ..<0x0384:
            .common
        case ..<0x0385:
            .greek
        case ..<0x0386:
            .common
        case ..<0x0387:
            .greek
        case ..<0x0388:
            .common
        case ..<0x03E2:
            .greek
        case ..<0x03F0:
            .coptic
        case ..<0x0400:
            .greek
        case ..<0x0485:
            .cyrillic
        case ..<0x0487:
            .inherited
        case ..<0x0531:
            .cyrillic
        case ..<0x0589:
            .armenian
        case ..<0x058A:
            .common
        case ..<0x0591:
            .armenian
        case ..<0x0600:
            .hebrew
        case ..<0x060C:
            .arabic
        case ..<0x060D:
            .common
        case ..<0x061B:
            .arabic
        case ..<0x061E:
            .common
        case ..<0x061F:
            .arabic
        case ..<0x0620:
            .common
        case ..<0x0640:
            .arabic
        case ..<0x0641:
            .common
        case ..<0x064B:
            .arabic
        case ..<0x0656:
            .inherited
        case ..<0x0660:
            .arabic
        case ..<0x066A:
            .common
        case ..<0x0670:
            .arabic
        case ..<0x0671:
            .inherited
        case ..<0x06DD:
            .arabic
        case ..<0x06DE:
            .common
        case ..<0x0700:
            .arabic
        case ..<0x0750:
            .syriac
        case ..<0x0780:
            .arabic
        case ..<0x07C0:
            .thaana
        case ..<0x0800:
            .nko
        case ..<0x0840:
            .samaritan
        case ..<0x08A0:
            .mandaic
        case ..<0x0900:
            .arabic
        case ..<0x0951:
            .devanagari
        case ..<0x0953:
            .inherited
        case ..<0x0964:
            .devanagari
        case ..<0x0966:
            .common
        case ..<0x0981:
            .devanagari
        case ..<0x0A01:
            .bengali
        case ..<0x0A81:
            .gurmukhi
        case ..<0x0B01:
            .gujarati
        case ..<0x0B82:
            .oriya
        case ..<0x0C01:
            .tamil
        case ..<0x0C82:
            .telugu
        case ..<0x0D02:
            .kannada
        case ..<0x0D82:
            .malayalam
        case ..<0x0E01:
            .sinhala
        case ..<0x0E3F:
            .thai
        case ..<0x0E40:
            .common
        case ..<0x0E81:
            .thai
        case ..<0x0F00:
            .lao
        case ..<0x0FD5:
            .tibetan
        case ..<0x0FD9:
            .common
        case ..<0x1000:
            .tibetan
        case ..<0x10A0:
            .myanmar
        case ..<0x10FB:
            .georgian
        case ..<0x10FC:
            .common
        case ..<0x1100:
            .georgian
        case ..<0x1200:
            .hangul
        case ..<0x13A0:
            .ethiopic
        case ..<0x1400:
            .cherokee
        case ..<0x1680:
            .canadianAboriginal
        case ..<0x16A0:
            .ogham
        case ..<0x16EB:
            .runic
        case ..<0x16EE:
            .common
        case ..<0x1700:
            .runic
        case ..<0x1720:
            .tagalog
        case ..<0x1735:
            .hanunoo
        case ..<0x1740:
            .common
        case ..<0x1760:
            .buhid
        case ..<0x1780:
            .tagbanwa
        case ..<0x1800:
            .khmer
        case ..<0x1802:
            .mongolian
        case ..<0x1804:
            .common
        case ..<0x1805:
            .mongolian
        case ..<0x1806:
            .common
        case ..<0x18B0:
            .mongolian
        case ..<0x1900:
            .canadianAboriginal
        case ..<0x1950:
            .limbu
        case ..<0x1980:
            .taiLe
        case ..<0x19E0:
            .newTaiLue
        case ..<0x1A00:
            .khmer
        case ..<0x1A20:
            .buginese
        case ..<0x1B00:
            .taiTham
        case ..<0x1B80:
            .balinese
        case ..<0x1BC0:
            .sundanese
        case ..<0x1C00:
            .batak
        case ..<0x1C50:
            .lepcha
        case ..<0x1CC0:
            .olChiki
        case ..<0x1CD0:
            .sundanese
        case ..<0x1CD3:
            .inherited
        case ..<0x1CD4:
            .common
        case ..<0x1CE1:
            .inherited
        case ..<0x1CE2:
            .common
        case ..<0x1CE9:
            .inherited
        case ..<0x1CED:
            .common
        case ..<0x1CEE:
            .inherited
        case ..<0x1CF4:
            .common
        case ..<0x1CF5:
            .inherited
        case ..<0x1D00:
            .common
        case ..<0x1D26:
            .latin
        case ..<0x1D2B:
            .greek
        case ..<0x1D2C:
            .cyrillic
        case ..<0x1D5D:
            .latin
        case ..<0x1D62:
            .greek
        case ..<0x1D66:
            .latin
        case ..<0x1D6B:
            .greek
        case ..<0x1D78:
            .latin
        case ..<0x1D79:
            .cyrillic
        case ..<0x1DBF:
            .latin
        case ..<0x1DC0:
            .greek
        case ..<0x1E00:
            .inherited
        case ..<0x1F00:
            .latin
        case ..<0x2000:
            .greek
        case ..<0x200C:
            .common
        case ..<0x200E:
            .inherited
        case ..<0x2071:
            .common
        case ..<0x2074:
            .latin
        case ..<0x207F:
            .common
        case ..<0x2080:
            .latin
        case ..<0x2090:
            .common
        case ..<0x20A0:
            .latin
        case ..<0x20D0:
            .common
        case ..<0x2100:
            .inherited
        case ..<0x2126:
            .common
        case ..<0x2127:
            .greek
        case ..<0x212A:
            .common
        case ..<0x212C:
            .latin
        case ..<0x2132:
            .common
        case ..<0x2133:
            .latin
        case ..<0x214E:
            .common
        case ..<0x214F:
            .latin
        case ..<0x2160:
            .common
        case ..<0x2189:
            .latin
        case ..<0x2800:
            .common
        case ..<0x2900:
            .braille
        case ..<0x2C00:
            .common
        case ..<0x2C60:
            .glagolitic
        case ..<0x2C80:
            .latin
        case ..<0x2D00:
            .coptic
        case ..<0x2D30:
            .georgian
        case ..<0x2D80:
            .tifinagh
        case ..<0x2DE0:
            .ethiopic
        case ..<0x2E00:
            .cyrillic
        case ..<0x2E80:
            .common
        case ..<0x2FF0:
            .han
        case ..<0x3005:
            .common
        case ..<0x3006:
            .han
        case ..<0x3007:
            .common
        case ..<0x3008:
            .han
        case ..<0x3021:
            .common
        case ..<0x302A:
            .han
        case ..<0x302E:
            .inherited
        case ..<0x3030:
            .hangul
        case ..<0x3038:
            .common
        case ..<0x303C:
            .han
        case ..<0x3041:
            .common
        case ..<0x3099:
            .hiragana
        case ..<0x309B:
            .inherited
        case ..<0x309D:
            .common
        case ..<0x30A0:
            .hiragana
        case ..<0x30A1:
            .common
        case ..<0x30FB:
            .katakana
        case ..<0x30FD:
            .common
        case ..<0x3105:
            .katakana
        case ..<0x3131:
            .bopomofo
        case ..<0x3190:
            .hangul
        case ..<0x31A0:
            .common
        case ..<0x31C0:
            .bopomofo
        case ..<0x31F0:
            .common
        case ..<0x3200:
            .katakana
        case ..<0x3220:
            .hangul
        case ..<0x3260:
            .common
        case ..<0x327F:
            .hangul
        case ..<0x32D0:
            .common
        case ..<0x3358:
            .katakana
        case ..<0x3400:
            .common
        case ..<0x4DC0:
            .han
        case ..<0x4E00:
            .common
        case ..<0xA000:
            .han
        case ..<0xA4D0:
            .yi
        case ..<0xA500:
            .lisu
        case ..<0xA640:
            .vai
        case ..<0xA6A0:
            .cyrillic
        case ..<0xA700:
            .bamum
        case ..<0xA722:
            .common
        case ..<0xA788:
            .latin
        case ..<0xA78B:
            .common
        case ..<0xA800:
            .latin
        case ..<0xA830:
            .sylotiNagri
        case ..<0xA840:
            .common
        case ..<0xA880:
            .phagsPa
        case ..<0xA8E0:
            .saurashtra
        case ..<0xA900:
            .devanagari
        case ..<0xA930:
            .kayahLi
        case ..<0xA960:
            .rejang
        case ..<0xA980:
            .hangul
        case ..<0xAA00:
            .javanese
        case ..<0xAA60:
            .cham
        case ..<0xAA80:
            .myanmar
        case ..<0xAAE0:
            .taiViet
        case ..<0xAB01:
            .meeteiMayek
        case ..<0xABC0:
            .ethiopic
        case ..<0xAC00:
            .meeteiMayek
        case ..<0xD7FC:
            .hangul
        case ..<0xF900:
            .unknown
        case ..<0xFB00:
            .han
        case ..<0xFB13:
            .latin
        case ..<0xFB1D:
            .armenian
        case ..<0xFB50:
            .hebrew
        case ..<0xFD3E:
            .arabic
        case ..<0xFD50:
            .common
        case ..<0xFDFD:
            .arabic
        case ..<0xFE00:
            .common
        case ..<0xFE10:
            .inherited
        case ..<0xFE20:
            .common
        case ..<0xFE30:
            .inherited
        case ..<0xFE70:
            .common
        case ..<0xFEFF:
            .arabic
        case ..<0xFF21:
            .common
        case ..<0xFF3B:
            .latin
        case ..<0xFF41:
            .common
        case ..<0xFF5B:
            .latin
        case ..<0xFF66:
            .common
        case ..<0xFF70:
            .katakana
        case ..<0xFF71:
            .common
        case ..<0xFF9E:
            .katakana
        case ..<0xFFA0:
            .common
        case ..<0xFFE0:
            .hangul
        case ..<0x10000:
            .common
        case ..<0x10100:
            .linearB
        case ..<0x10140:
            .common
        case ..<0x10190:
            .greek
        case ..<0x101FD:
            .common
        case ..<0x10280:
            .inherited
        case ..<0x102A0:
            .lycian
        case ..<0x10300:
            .carian
        case ..<0x10330:
            .oldItalic
        case ..<0x10380:
            .gothic
        case ..<0x103A0:
            .ugaritic
        case ..<0x10400:
            .oldPersian
        case ..<0x10450:
            .deseret
        case ..<0x10480:
            .shavian
        case ..<0x10800:
            .osmanya
        case ..<0x10840:
            .cypriot
        case ..<0x10900:
            .imperialAramaic
        case ..<0x10920:
            .phoenician
        case ..<0x10980:
            .lydian
        case ..<0x109A0:
            .meroiticHieroglyphs
        case ..<0x10A00:
            .meroiticCursive
        case ..<0x10A60:
            .kharoshthi
        case ..<0x10B00:
            .oldSouthArabian
        case ..<0x10B40:
            .avestan
        case ..<0x10B60:
            .inscriptionalParthian
        case ..<0x10C00:
            .inscriptionalPahlavi
        case ..<0x10E60:
            .oldTurkic
        case ..<0x11000:
            .arabic
        case ..<0x11080:
            .brahmi
        case ..<0x110D0:
            .kaithi
        case ..<0x11100:
            .soraSompeng
        case ..<0x11180:
            .chakma
        case ..<0x11680:
            .sharada
        case ..<0x12000:
            .takri
        case ..<0x13000:
            .cuneiform
        case ..<0x16800:
            .egyptianHieroglyphs
        case ..<0x16F00:
            .bamum
        case ..<0x1B000:
            .miao
        case ..<0x1B001:
            .katakana
        case ..<0x1D000:
            .hiragana
        case ..<0x1D167:
            .common
        case ..<0x1D16A:
            .inherited
        case ..<0x1D17B:
            .common
        case ..<0x1D183:
            .inherited
        case ..<0x1D185:
            .common
        case ..<0x1D18C:
            .inherited
        case ..<0x1D1AA:
            .common
        case ..<0x1D1AE:
            .inherited
        case ..<0x1D200:
            .common
        case ..<0x1D300:
            .greek
        case ..<0x1EE00:
            .common
        case ..<0x1F000:
            .arabic
        case ..<0x1F200:
            .common
        case ..<0x1F201:
            .hiragana
        case ..<0x20000:
            .common
        case ..<0xE0001:
            .han
        case ..<0xE0100:
            .common
        case ..<0xE01F0:
            .inherited
        default:
            .unknown
        }
    }
}
