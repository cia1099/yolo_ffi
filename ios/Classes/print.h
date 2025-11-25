#ifndef PRINT_H
#define PRINT_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Sends a message string to the native side (Android/iOS), which should
 * then forward it to Dart via an EventChannel.
 *
 * @param message The C-style string message to send.
 */
void print_message(const char* message);

#ifdef __cplusplus
}
#endif

#endif // PRINT_H