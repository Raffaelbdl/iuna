package io.github.raffaelbdl.iuna

import androidx.core.content.FileProvider

// Its own subclass, so the manifest merger can't fold it into a plugin's
// FileProvider entry.
class UpdateFileProvider : FileProvider()
