import AppKit

/// Concrete text storage that does **not** perform AppKit's font substitution.
///
/// The bundled `Commodore-64-v6.3.TTF` face has empty Unicode coverage metadata.
/// Default `NSTextStorage` / `fixAttributes(in:)` then replaces it with Helvetica
/// (or can leave text invisible after some cascade-list workarounds). This subclass
/// stores attributes in an `NSMutableAttributedString` and skips font fixing.
final class Ready64TextStorage: NSTextStorage {
    private let backing = NSMutableAttributedString()

    override var string: String {
        backing.string
    }

    override func attributes(
        at location: Int,
        effectiveRange range: NSRangePointer?
    ) -> [NSAttributedString.Key: Any] {
        backing.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backing.replaceCharacters(in: range, with: str)
        edited(
            .editedCharacters,
            range: range,
            changeInLength: (str as NSString).length - range.length
        )
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backing.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    /// Prevent AppKit from substituting Helvetica for Commodore64.
    override func fixAttributes(in range: NSRange) {
        // Intentionally do not call super.
    }
}
