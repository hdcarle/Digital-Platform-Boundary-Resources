# Programming Languages Index

**Source**: CODE_BOOK_v_2_5_26.xlsx, Tab: "Programming languages"

This is the official list of valid programming languages for coding boundary resources. Use this list for all `_prog_lang_list` variables:
- SDK_prog_lang_list
- GIT_prog_lang_list
- BUG_prog_lang_list
- programming_lang_variety_list

---

## Valid Programming Languages (50 total)

| # | Language | Notes |
|---|----------|-------|
| 1 | Ada | |
| 2 | Apex | Salesforce proprietary |
| 3 | Assembly | |
| 4 | Bash/Shell | |
| 5 | C | |
| 6 | C# | .NET, Unity |
| 7 | C++ | Unreal Engine |
| 8 | Clojure | |
| 9 | Cobol | |
| 10 | Crystal | |
| 11 | Dart | Flutter uses Dart |
| 12 | Delphi | |
| 13 | Elixir | |
| 14 | Erlang | |
| 15 | F# | .NET |
| 16 | Fortran | |
| 17 | GDScript | Godot Engine |
| 18 | Go | Also called Golang |
| 19 | Groovy | |
| 20 | Haskell | |
| 21 | HTML/CSS | Web markup |
| 22 | Java | Android |
| 23 | JavaScript | Node.js, Web |
| 24 | Julia | |
| 25 | Kotlin | Android |
| 26 | Lisp | |
| 27 | Lua | Game scripting |
| 28 | MATLAB | |
| 29 | MicroPython | |
| 30 | Nim | |
| 31 | Objective-C | iOS legacy |
| 32 | OCaml | |
| 33 | Perl | |
| 34 | PHP | |
| 35 | PowerShell | |
| 36 | Prolog | |
| 37 | Python | |
| 38 | R | |
| 39 | Ruby | |
| 40 | Rust | |
| 41 | Scala | |
| 42 | Solidity | Blockchain |
| 43 | SQL | |
| 44 | Swift | iOS |
| 45 | TypeScript | |
| 46 | VBA | |
| 47 | Visual Basic | |
| 48 | Zephyr | RTOS |

---

## NOT Programming Languages

The following are NOT valid programming languages for this codebook:

### Game Engines / Development Platforms
- ❌ Unity → Use **C#**
- ❌ Unreal / Unreal Engine → Use **C++**
- ❌ Godot → Use **GDScript** or **C#**
- ❌ Native → Specify the actual language (C, C++, Swift, etc.)

### Mobile Platforms
- ❌ iOS → Use **Swift** and/or **Objective-C**
- ❌ Android → Use **Java** and/or **Kotlin**
- ❌ Flutter → Use **Dart**
- ❌ React Native → Use **JavaScript**
- ❌ Xamarin → Use **C#**

### Frameworks / Runtimes (NOT languages)
- ❌ .NET → Use **C#** or **F#**
- ❌ Node.js → Use **JavaScript**
- ❌ Spring → Use **Java**
- ❌ Django → Use **Python**
- ❌ Rails → Use **Ruby**
- ❌ Express → Use **JavaScript**
- ❌ Laravel → Use **PHP**

### Build Tools / Package Managers (NOT languages)
- ❌ CMake
- ❌ Gradle
- ❌ Maven
- ❌ npm
- ❌ pip
- ❌ Cargo

### Data/Markup Formats (NOT languages, except HTML/CSS)
- ❌ JSON
- ❌ XML
- ❌ YAML
- ❌ Markdown
- ✓ HTML/CSS (this IS valid)

### Shader Languages
- ❌ HLSL → Consider noting separately or mapping to C++
- ❌ GLSL → Consider noting separately or mapping to C
- ❌ ShaderLab → Unity-specific, use C#

---

## Mapping Rules

When you encounter platform/framework names, translate to the underlying programming language:

| If you see... | Record as... |
|---------------|--------------|
| Unity SDK | C# |
| Unreal SDK | C++ |
| Node.js SDK | JavaScript |
| .NET SDK | C# |
| Android SDK | Java; Kotlin |
| iOS SDK | Swift; Objective-C |
| Flutter SDK | Dart |
| React Native | JavaScript |
| Web SDK | JavaScript |

---

## Examples

### Correct Coding:
**Platform offers SDKs for Unity, Unreal, and Python**
- SDK_prog_lang = 3
- SDK_prog_lang_list = "C#; C++; Python"

### Incorrect Coding:
- ❌ SDK_prog_lang_list = "Unity; Unreal; Python"

---

## Source Reference

This index is based on Stack Overflow Developer Survey language rankings and standard industry practice for categorizing programming languages vs. platforms/frameworks.
