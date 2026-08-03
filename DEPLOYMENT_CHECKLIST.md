# HashPC Production Deployment Checklist

## 🔐 Security Pre-Deployment

### Firebase Console Setup
- [ ] Create new Firebase project named "hashpc"
- [ ] Enable Email/Password authentication
- [ ] Create Realtime Database (Asia Southeast-1 region)
- [ ] Create default admin user:
  - Email: `PUT_YOUR_FIREBASE_EMAIL_HERE`
  - Password: `PUT_YOUR_FIREBASE_PASSWORD_HERE`
- [ ] Deploy RTDB Rules from `firebase/rtdb_rules.json`
  - Go to Database > Rules tab
  - Copy entire JSON file content
  - Click Publish
- [ ] Enable Firestore (optional, if needed later)
- [ ] Set up Cloud Storage for OTA updates (future)
- [ ] Enable Firebase Monitoring

### Security Changes (CRITICAL - Do Before Production)

- [ ] **CHANGE DEFAULT PASSWORD** in Firebase Authentication
  1. Go to Authentication > Users
  2. Click on user account
  3. Click "Reset Password"
  4. Send reset link
  5. Create new secure password

- [ ] **Enable Multi-Factor Authentication** for admin account
  1. In Firebase Console > Authentication
  2. Enable "Multi-factor authentication"

- [ ] **Set Firebase Rules to PRODUCTION MODE**
  - Review rules in `firebase/rtdb_rules.json`
  - Rules follow principle of least privilege
  - Rules included in project - deploy them

- [ ] **Update ESP32 Credentials**
  - Change Firebase email in `config.h`
  - Change Firebase password in `config.h`
  - Or use captive portal to reconfigure

- [ ] **Update Flutter App Credentials**
  - Verify credentials in `lib/services/firebase_options.dart`
  - Use production Firebase project settings

- [ ] **Secure Captive Portal**
  - Change default AP password in `config.h`
  - Change AP name if desired
  - Only allow authenticated access

- [ ] **Enable HTTPS Everywhere**
  - All Firebase calls use HTTPS by default ✓
  - Verify no HTTP fallbacks in code
  - Test with Charles/Mitmproxy if concerned

### Environment Configuration

- [ ] Set up separate Firebase projects for:
  - [ ] Development
  - [ ] Staging (optional)
  - [ ] Production

- [ ] Create environment-specific credentials
  - Development: Use test credentials
  - Production: Use production credentials

- [ ] Configure database backup
  - Enable automatic backups in Firebase Console
  - Set retention policy (minimum 30 days)

## 🔧 Hardware Pre-Deployment

### ESP32-S3-ETH Board Setup

- [ ] Verify board is Waveshare ESP32-S3-ETH
- [ ] Check all GPIO pins are correct for your relay module
- [ ] Verify W5500 Ethernet module is soldered correctly
- [ ] Check RGB LED onboard
- [ ] Verify power supply (5V minimum 2A)

### Relay Module Setup

- [ ] Check all 4 relays are connected to correct GPIO pins
  - [ ] Relay 1 → GPIO33
  - [ ] Relay 2 → GPIO34
  - [ ] Relay 3 → GPIO35
  - [ ] Relay 4 → GPIO36
- [ ] Verify relay power supply (12V typical)
- [ ] Check relay switching voltage matches target devices
- [ ] Test each relay with multimeter before connection to devices
- [ ] Verify relay activation polarity (activeLow setting)
- [ ] Connect load devices safely:
  - [ ] PC Power → Relay 1 (hot wire only!)
  - [ ] Monitor 1 → Relay 2
  - [ ] Monitor 2 → Relay 3
  - [ ] PC Power Button → Relay 4 (front panel header)

### Network Setup

- [ ] Connect Ethernet cable to device
- [ ] Verify network connectivity
- [ ] Test internet connectivity (device can reach 8.8.8.8)
- [ ] Verify DNS resolution works
- [ ] Check for firewall blocks (port 443 for Firebase)

### LED & Indicator Setup

- [ ] Test RGB LED displays all 4 colors correctly
- [ ] Verify Status LED (GPIO47) blinks properly
- [ ] Verify Network LED (GPIO48) responds to state changes
- [ ] Test Buzzer (GPIO46) if applicable

## 📱 Flutter App Pre-Deployment

### Build & Testing

- [ ] Run `flutter pub get` to install dependencies
- [ ] Run `flutter pub run build_runner build` for Hive
- [ ] Build release APK: `flutter build apk --release`
- [ ] Test on Android device (minimum Android 6.0)
- [ ] Test on iPad/tablet for responsive layout
- [ ] Test login with correct credentials
- [ ] Test device connection and relay control
- [ ] Test offline behavior (expected: queued)
- [ ] Test error messages display correctly
- [ ] Test network status indicators

### App Configuration

- [ ] Verify Firebase credentials in `firebase_options.dart`
- [ ] Check API key is production key
- [ ] Verify project ID is correct
- [ ] Confirm auth domain is correct
- [ ] Check database URL is correct

### Performance Testing

- [ ] Monitor app memory usage (should be < 100MB)
- [ ] Test with slow network (throttle to 3G)
- [ ] Verify UI responsive with 4-8 relays
- [ ] Check battery consumption (normal usage)
- [ ] Profile startup time (should be < 2 seconds)

## 🔌 Firmware Pre-Deployment

### Compilation & Upload

- [ ] Verify Arduino IDE or PlatformIO installed
- [ ] Install required libraries:
  - [ ] ArduinoJson (Benoit Blanchon)
  - [ ] Adafruit NeoPixel
- [ ] Select correct board: ESP32S3 Dev Module
- [ ] Compile without errors
- [ ] Upload to device without errors
- [ ] Verify upload success message

### Firmware Testing

- [ ] Device boots successfully
- [ ] Serial output shows boot messages at 115200 baud
- [ ] Captive portal broadcasts Wi-Fi
- [ ] Portal accessible at http://192.168.4.1
- [ ] Can login with Firebase credentials
- [ ] Can access settings page
- [ ] NVS configuration saves and persists after reboot
- [ ] Device connects to Ethernet
- [ ] Device authenticates to Firebase
- [ ] RGB LED shows correct status:
  - [ ] Blue (no ethernet)
  - [ ] Orange (no internet)
  - [ ] Green (ready)
- [ ] Each relay responds to GPIO command (< 50ms)
- [ ] Device responds to Firebase commands
- [ ] Relay state updates to Firebase status
- [ ] Device survives network interruptions
- [ ] Device reconnects after power cycle

### Serial Debugging

- [ ] Monitor serial output: `platformio run -e esp32-s3-eth --target monitor`
- [ ] Verify no errors in output
- [ ] Check network status updates every 30 seconds
- [ ] Verify relay commands logged correctly
- [ ] Check Firebase sync every 5 seconds
- [ ] Monitor for memory leaks (heap free should stabilize)

## 📊 Integration Testing

### End-to-End Tests

- [ ] Device boots → authenticates → shows ready
- [ ] Flutter app login → loads device → shows online
- [ ] Toggle relay in app → executes on device → updates in app
- [ ] Change device config → saved to Firebase → persists on reboot
- [ ] Multiple users → can control same device
- [ ] Offline command → queued → executes when online
- [ ] Network failure → device reconnects automatically
- [ ] Firebase token expiry → refreshed automatically

### Multi-User Testing

- [ ] Create second Firebase user
- [ ] Add to device allowedUsers list
- [ ] Second user can login and control device
- [ ] Device logs both users' actions
- [ ] Both apps see real-time updates from each other

### Stress Testing

- [ ] Rapid relay toggles → device handles without errors
- [ ] Multiple app instances → sync correctly
- [ ] Network interruptions → graceful reconnection
- [ ] Extended run time (24+ hours) → stable

## ✅ Pre-Launch Final Checks

### Documentation Review

- [ ] All README files are up-to-date
- [ ] GPIO pin mappings documented correctly
- [ ] Firebase credentials stored securely
- [ ] Deployment steps documented clearly
- [ ] Troubleshooting guide covers common issues
- [ ] Emergency shutdown procedure documented

### Backup & Recovery

- [ ] Backup Firebase database configuration
- [ ] Document factory reset procedure
- [ ] Create device configuration backup
- [ ] Document recovery steps for each component
- [ ] Store backup credentials securely

### Monitoring Setup

- [ ] Enable Firebase Realtime Database metrics
- [ ] Set up alerts for authentication failures
- [ ] Monitor database read/write counts
- [ ] Track active connections
- [ ] Set quota alerts (free tier: 100 concurrent)

### Logs & Metrics

- [ ] Configure Firebase logging
- [ ] Enable device log collection
- [ ] Set up log retention policy
- [ ] Document log access procedure
- [ ] Plan log analysis frequency

## 🚨 Production Incident Response

### What to Do If Problems Occur

**Device won't boot:**
1. Check USB power supply
2. Verify board is not damaged
3. Try re-uploading firmware
4. Check serial output for error messages

**Firebase authentication fails:**
1. Verify internet connectivity
2. Check Firebase credentials in config
3. Verify Firebase project is accessible
4. Check security rules aren't blocking
5. Verify user account exists

**Relays unresponsive:**
1. Check GPIO pin assignments
2. Verify relay module power
3. Test with multimeter
4. Check relay for physical damage
5. Review serial output for errors

**App crashes:**
1. Check Firebase initialization
2. Clear app cache/data
3. Re-install app
4. Check Flutter console errors
5. Review Firebase console logs

## 📞 Production Support Contacts

- [ ] Document Firebase support contact
- [ ] Note escalation procedures
- [ ] List internal support team
- [ ] Document on-call rotation
- [ ] Create incident response playbook

## 🎯 Post-Deployment

### Day 1 Monitoring

- [ ] Monitor Firebase console for errors
- [ ] Check device logs for issues
- [ ] Verify relays working as expected
- [ ] Monitor network connectivity
- [ ] Track app performance

### Week 1 Follow-up

- [ ] Review device logs for patterns
- [ ] Monitor Firebase quota usage
- [ ] Gather user feedback
- [ ] Document any issues found
- [ ] Create improvement list

### Monthly Review

- [ ] Analyze usage patterns
- [ ] Check security audit logs
- [ ] Review database performance
- [ ] Plan maintenance window if needed
- [ ] Update documentation

## ✨ Launch Readiness Certification

- [ ] All security items checked ✓
- [ ] All hardware items checked ✓
- [ ] All firmware items checked ✓
- [ ] All app items checked ✓
- [ ] All integration items checked ✓
- [ ] All pre-launch items checked ✓
- [ ] All documentation items checked ✓

**Status: Ready for Production Deployment ✅**

**Deployment Date**: _____________
**Deployed By**: _____________
**Witnessed By**: _____________

---

**Important Notes:**

⚠️ **SECURITY**: Change default password before going live
⚠️ **BACKUPS**: Enable Firebase backups immediately
⚠️ **MONITORING**: Set up alerts on Firebase console
⚠️ **TESTING**: Test emergency power button procedure
⚠️ **DOCUMENTATION**: Keep credentials in secure location

---

**Next Review Date**: 30 days post-deployment

For questions: Refer to `IMPLEMENTATION_GUIDE.md` and component READMEs.
