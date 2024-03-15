## 0.4.1 - 2024-03-13

### Improved
- Removed GenServer from `Anthropic.Config`. It will be created from `Application.get_env` or from the supplied options.
- Added Mox to test environment.
- Increased test coverage.

### Breaking change
- Changed the tool field type to MapSet

### Improved
- Better system function concatenation with tools description
- Moved List.reverse from messages to Jason.Encoder implementation.

## 0.4.0 - 2024-03-13

### Improved
- Added tools handling. Now you can register tools that the AI can call, and these calls are automaticaly captured.

### Fixed
- The way Messages.content was being generated

### Minor
- Moved Response parsing to Request module.

### Breaking change
- Replaced `Anthropic.add_image/2` with `Anthropic.add_user_image/2`

## 0.3.0 - 2024-03-12

### Improved
- Included telemetry
- Added threatment of nil `api_key`

## 0.2.1 - 2024-03-11

### Fixed
- Removed guard that would not allow assistant message to be added to request
- Process response with Jason.decode.

### Improved
- Added type annotations to documentatio

## 0.2.0 - 2024-03-11

### Improved
- Added support for image content
