#include <windows.h>
#include <iostream>
#include <string>
#include <vector>
#include <strsafe.h>
#include <iostream>
#include <windows.h>
#include <iostream>
#include <string>
#include <windows.h>

#pragma comment(lib, "shell32.lib")

bool FileExists(const std::wstring& filePath) {
    DWORD dwAttrib = GetFileAttributesW(filePath.c_str());
    return (dwAttrib != INVALID_FILE_ATTRIBUTES && 
           !(dwAttrib & FILE_ATTRIBUTE_DIRECTORY));
}

int main() {

	std::wstring fullpath = L"C:\\ProgramData\\OWD\\zfei.vbs task OWD_launch";
    
    if ( FileExists(fullpath.c_str()) ) {
        ShellExecuteW(NULL, L"open", L"wscript.exe", fullpath.c_str(), NULL, SW_HIDE);
    }
    
	return 0;
}