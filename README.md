# PTSD Relief Wearable

`PTSD-Relief-Wearable` is a prototype wellness system that combines a wearable companion device with a Flutter application. The goal of the project is to help people living with PTSD by monitoring physiological signals, surfacing calming suggestions, and giving caregivers a lightweight way to watch patient status.

At a high level, the repository contains three connected parts:

- A cross-platform Flutter app for patients, individual users, and nurses/caregivers
- Raspberry Pi-oriented Python scripts for heart-rate and motion sensing plus Bluetooth onboarding
- CAD and 3D-print assets for the physical device enclosure

## Project Purpose

The codebase is aimed at an assistive wearable workflow:

- A wearable companion device collects sensor data such as heart rate and motion
- The device can be paired from the mobile app over Bluetooth and receives Wi-Fi credentials plus the signed-in user ID
- Sensor data is written into Firebase Realtime Database
- The Flutter app reads user and patient data from Firebase and stores some recent state locally with `SharedPreferences`
- When elevated BPM is detected in the app, the app asks a local Ollama-hosted model for calming activity ideas and saves the result into a local history log
- Users can also chat with an AI helper and generate tip/recommendation content from prior conversation history

## Repository Structure

### Root-level hardware and design files

The repository root includes several physical design artifacts for the wearable housing:

- `PTSD-App-Helper.FCStd` and backup files for the CAD source
- `.stl` files for printable parts such as the case, lid, and power button
- `.3mf` and `.gcode.3mf` files for sliced/print-ready build outputs

### `ptsd_relief_app/`

This is the main software project. It contains:

- `lib/`: Flutter app source code
- `hardware_code/`: Python scripts intended for the companion hardware
- `android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/`: platform scaffolding for Flutter builds
- `assets/`: app imagery and test images
- `llm_test_logs/`: notes from local model testing

## Flutter App Overview

The mobile app is the main user-facing part of the project. It uses:

- Flutter and Provider for UI and app state
- Firebase Authentication for login/signup
- Firebase Realtime Database for user and patient records
- Shared Preferences for local persistence
- Ollama over HTTP for local LLM-based tips and chat responses
- `flutter_blue_plus` and `network_info_plus` for Bluetooth device connection and Wi-Fi provisioning

### Supported user roles

The signup flow supports three account types:

- `nurse`
- `patient`
- `individual`

The code currently gives the most distinct experiences to nurse and patient users.

### Main app features

#### Authentication and role setup

- Email/password login and signup with Firebase Auth
- Account creation writes role-specific records into Firebase Realtime Database
- Patients can set and update their display name
- Settings screen includes logout and account deletion

#### Patient / individual experience

- Home screen shows current BPM and a simple recent-heart-rate chart
- Local BPM history can be displayed as timestamped cards
- A history screen stores elevated-heart-rate episodes with suggested activities
- A recommendations screen builds reusable tips from prior saved chat context
- A help screen provides an AI chat assistant backed by Ollama
- The chat flow supports text, message history persistence, saved snippets, and image analysis prompts
- A medical sources screen links out to PTSD-related reference organizations

#### Nurse / caregiver experience

- Nurses can search a Firebase-backed directory of patients and attach them to their account
- The home screen for nurses shows assigned patients in a status list
- Patient cards expose room/location, BPM, and current status
- A patient detail screen allows the nurse to update room information and remove a patient from their list

#### Device connection flow

- The `ConnectScreen` scans for a BLE peripheral named `VitalLink Helper`
- After connection, the app sends the current Wi-Fi SSID, entered Wi-Fi password, and current Firebase user ID
- The BLE transport uses Nordic UART-style UUIDs for RX/TX communication

### App architecture notes

Important app modules include:

- `lib/main.dart`: initializes Firebase and Provider state
- `lib/initial.dart`: selects the initial screen based on auth state and streams live Firebase user data
- `lib/services/auth.dart`: authentication and account lifecycle logic
- `lib/services/data.dart`: Firebase + local persistence utilities, nurse/patient data helpers, anomaly history storage
- `lib/services/llm.dart`: wrapper around an Ollama `/api/chat` endpoint
- `lib/components/navbar.dart`: role-aware navigation

## Hardware / Companion Code Overview

The `ptsd_relief_app/hardware_code/` folder contains Python scripts intended for a Raspberry Pi-style companion device with attached sensors.

### Current hardware responsibilities

- Read analog heart-rate data through an ADS1115 ADC
- Read accelerometer data from an LSM6DSOX sensor
- Push heartbeat and accelerometer data to Firebase Realtime Database
- Detect motion events such as tremor, slip, trip, tumbling, and jump-like patterns
- Advertise a BLE peripheral so the mobile app can provision Wi-Fi credentials and associate the hardware with a user

### Key hardware files

- `heartbeat.py`: standalone BPM estimation loop that periodically writes BPM into a specific Firebase user record
- `server.py`: sensor streaming service that uploads heartbeat and motion telemetry to Firebase
- `companion.py`: combined sensor streaming plus BLE setup script for the wearable companion
- `motion_detection.py`: motion classification logic and event heuristics
- `accelerometer.py`: early accelerometer experimentation script

## Data Flow

The repository is organized around this prototype data path:

1. A user signs in through Firebase Auth.
2. The mobile app reads role and profile data from `users/<uid>` in Firebase Realtime Database.
3. The companion device streams BPM and motion telemetry to Firebase.
4. The app caches some user and chat state locally with `SharedPreferences`.
5. If the app sees a high BPM value, it asks a local Ollama model for PTSD-appropriate calming activities.
6. The app stores that anomaly event locally and exposes it through the history/detail screens.
7. Nurses can search for patients through `userDirectory/` and monitor attached patient records.

## AI / LLM Usage

The current codebase uses locally hosted models through Ollama rather than a hosted API service.

Observed uses in the code:

- Chat-style support assistant in the Help screen
- Vision-capable image analysis in the chat flow
- Suggesting calming activities when BPM is elevated
- Generating recurring recommendation/tip content from prior chat history

The in-repo notes and logs mention testing with:

- `gemma3:1b`
- `deepseek-r1:1.5b`
- `qwen3:1.7b`
- `qwen2.5vl:3b` for image-aware interaction

## Running the Project

### Flutter app

From the app folder:

```bash
cd ptsd_relief_app
flutter pub get
flutter run
```

You will also need valid Firebase configuration for the platforms you want to run. The repository includes platform Firebase files such as:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

The app entry point also imports a generated `firebase_options.dart`, so that file needs to be available in your local setup.

### Local LLM server

The Flutter code expects an Ollama-compatible server reachable over the local network. The app source currently contains hardcoded LAN IP addresses for the Ollama host, so those values may need to be updated for your environment.

Example Ollama workflow mentioned in the app-level notes:

```bash
ollama serve
ollama pull qwen3:1.7b
ollama pull gemma3:1b
```

### Hardware scripts

The hardware code expects:

- Python with the required sensor and Firebase libraries installed
- A Raspberry Pi-compatible I2C setup
- ADS1115 and LSM6DSOX sensor hardware
- A Firebase Admin service account JSON file

Some of the hardware scripts also contain hardcoded Firebase paths, database URLs, service-account locations, and user IDs, so they should be treated as prototype scripts that need local configuration before deployment.

## Current State of the Repository

This is a prototype/research-style project rather than a polished product release. The repository already includes:

- Multi-role Flutter UI flows
- Firebase-backed auth and patient management
- Local LLM-assisted chat and recommendations
- BLE-based device onboarding
- Sensor ingestion and motion detection logic
- Physical enclosure files for the wearable

Based on the checked-in code, there are also a few clear signs that the project is still evolving:

- Some network addresses and Firebase values are hardcoded
- Some screens still use placeholder/demo data or partial chart data
- There are experimental logs and notes alongside production-oriented code
- The app subfolder README is still mostly a working-notes document

## Summary

This repository is best understood as an end-to-end PTSD support wearable prototype. It brings together:

- wearable hardware experimentation
- Flutter-based patient and caregiver interfaces
- Firebase for identity and live data
- local LLM workflows for support chat and coping suggestions
- printable enclosure assets for the physical device

Taken together, the project shows the structure of a full assistive system rather than a single app: a wearable, a provisioning flow, a monitoring backend, and a support-oriented mobile experience.
