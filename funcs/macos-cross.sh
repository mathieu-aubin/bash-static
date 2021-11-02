# Functions from https://github.com/xamarin/xamarin-android-binutils/blob/a9cf720d52b18c602b6be5a01905860d69f152ea/build.sh#L96
#
# MIT License
#
# Copyright (c) Microsoft Corporation.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE
#

function get_xcode_dir()
{
	local xcode_dir="$(xcode-select -p | head -1)"
	if [ $? -ne 0 ]; then
		die Could not find Xcode
	fi

	echo ${xcode_dir}
}

function configure_mac_compilers()
{
	local xcode_dir="$(get_xcode_dir)"
	export CC="${xcode_dir}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
	export CXX="${xcode_dir}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++"
}

function detect_mac_arch_flags()
{
	local xcode_dir="$(get_xcode_dir)"
	local sdksettings_path="${xcode_dir}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/SDKSettings.plist"
	local architectures="$(plutil -extract SupportedTargets.macosx.Archs json -o - "${sdksettings_path}")"

	if [ $? -ne 0 ]; then
		die Could not obtain the list of supported architectures from Xcode
	fi

	local flags=""

	if echo ${architectures} | grep '"arm64"' > /dev/null 2>&1; then
		flags="-arch arm64"
	fi

	if echo ${architectures} | grep '"x86_64"' > /dev/null 2>&1; then
		flags="${flags} -arch x86_64"
	fi

	local sysroot=""$(xcrun --sdk macosx --show-sdk-path)""

	#
	# The `-isysroot` and `-isystem` flags are required for autoconf to detect system headers when cross-compiling (which
	# technically is the case in the presence of multiple `-arch` arguments)
	#
	# Even though the search paths are set up correctly, autoconf fails to detect `string.h` when checking if all ANSI C
	# headers are defined (even though it detects it shortly after, "standalone"), so we need to define `STDC_HEADERS` here.
	# Similarly, `fcntl.h` is not detected (only in libiberty), so we force it here.
	#
	echo -n "${flags} -mmacosx-version-min=${MACOS_TARGET} -isysroot ${sysroot} -isystem ${sysroot} -DSTDC_HEADERS=1 -DHAVE_FCNTL_H"
}
