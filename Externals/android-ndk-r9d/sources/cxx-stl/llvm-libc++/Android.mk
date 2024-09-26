# This file is dual licensed under the MIT and the University of Illinois Open
# Source Licenses. See LICENSE.TXT for details.

LOCAL_PATH := $(call my-dir)

# Normally, we distribute the NDK with prebuilt binaries of libc++
# in $LOCAL_PATH/libs/<abi>/. However,
#

LIBCXX_FORCE_REBUILD := $(strip $(LIBCXX_FORCE_REBUILD))
ifndef LIBCXX_FORCE_REBUILD
  ifeq (,$(strip $(wildcard $(LOCAL_PATH)/libs/$(TARGET_ARCH_ABI)/libc++_static$(TARGET_LIB_EXTENSION))))
    $(call __ndk_info,WARNING: Rebuilding libc++ libraries from sources!)
    $(call __ndk_info,You might want to use $$NDK/build/tools/build-cxx-stl.sh --stl=libc++)
    $(call __ndk_info,in order to build prebuilt versions to speed up your builds!)
    LIBCXX_FORCE_REBUILD := true
  endif
endif

llvm_libc++_includes := $(LOCAL_PATH)/libcxx/include
llvm_libc++_export_includes := $(llvm_libc++_includes)
llvm_libc++_sources := \
	algorithm.cpp \
	bind.cpp \
	chrono.cpp \
	condition_variable.cpp \
	debug.cpp \
	exception.cpp \
	future.cpp \
	hash.cpp \
	ios.cpp \
	iostream.cpp \
	locale.cpp \
	memory.cpp \
	mutex.cpp \
	new.cpp \
	optional.cpp \
	random.cpp \
	regex.cpp \
	shared_mutex.cpp \
	stdexcept.cpp \
	string.cpp \
	strstream.cpp \
	system_error.cpp \
	thread.cpp \
	typeinfo.cpp \
	utility.cpp \
	valarray.cpp \
	support/android/locale_android.cpp

llvm_libc++_sources := $(llvm_libc++_sources:%=libcxx/src/%)

# For now, this library can only be used to build C++11 binaries.
llvm_libc++_export_cxxflags := -std=c++11

llvm_libc++_cxxflags := $(llvm_libc++_export_cxxflags)

# Gabi++ emulates libcxxabi when building libcxx.
#
llvm_libc++_cxxflags += -DLIBCXXABI=1

# Find the GAbi++ sources to include them here.
# The voodoo below is to allow building libc++ out of the NDK source
# tree. This can make it easier to experiment / update / debug it.
#
libgabi++_sources_dir := $(strip $(wildcard $(LOCAL_PATH)/../gabi++))
ifdef libgabi++_sources_dir
  libgabi++_sources_prefix := ../gabi++
else
  libgabi++_sources_dir := $(strip $(wildcard $(NDK_ROOT)/sources/cxx-stl/gabi++))
  ifndef libgabi++_sources_dir
    $(error Can't find GAbi++ sources directory!!)
  endif
  libgabi++_sources_prefix := $(libgabi++_sources_dir)
endif

include $(libgabi++_sources_dir)/sources.mk
llvm_libc++_sources += $(addprefix $(libgabi++_sources_prefix:%/=%)/,$(libgabi++_src_files))
llvm_libc++_includes += $(libgabi++_c_includes)
llvm_libc++_export_includes += $(libgabi++_c_includes)

ifneq ($(LIBCXX_FORCE_REBUILD),true)

$(call ndk_log,Using prebuilt libc++ libraries)

android_support_c_includes := $(LOCAL_PATH)/../../android/support/include

include $(CLEAR_VARS)
LOCAL_MODULE := c++_static
LOCAL_SRC_FILES := libs/$(TARGET_ARCH_ABI)/lib$(LOCAL_MODULE)$(TARGET_LIB_EXTENSION)
LOCAL_EXPORT_C_INCLUDES := $(llvm_libc++_export_includes) $(android_support_c_includes)
LOCAL_EXPORT_CPPFLAGS := $(llvm_libc++_export_cxxflags)
include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE := c++_shared
LOCAL_SRC_FILES := libs/$(TARGET_ARCH_ABI)/lib$(LOCAL_MODULE)$(TARGET_SONAME_EXTENSION)
LOCAL_EXPORT_C_INCLUDES := $(llvm_libc++_export_includes) $(android_support_c_includes)
LOCAL_EXPORT_CPPFLAGS := $(llvm_libc++_export_cxxflags)
include $(PREBUILT_SHARED_LIBRARY)

else # LIBCXX_FORCE_REBUILD == true

$(call ndk_log,Rebuilding libc++ libraries from sources)

include $(CLEAR_VARS)
LOCAL_MODULE := c++_static
LOCAL_SRC_FILES := $(llvm_libc++_sources)
LOCAL_C_INCLUDES := $(llvm_libc++_includes)
LOCAL_CPPFLAGS := $(llvm_libc++_cxxflags)
LOCAL_CPP_FEATURES := rtti exceptions
LOCAL_EXPORT_C_INCLUDES := $(llvm_libc++_export_includes)
LOCAL_EXPORT_CPPFLAGS := $(llvm_libc++_export_cxxflags)
LOCAL_STATIC_LIBRARIES := android_support
include $(BUILD_STATIC_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE := c++_shared
LOCAL_SRC_FILES := $(llvm_libc++_sources)
LOCAL_C_INCLUDES := $(llvm_libc++_includes)
LOCAL_CPPFLAGS := $(llvm_libc++_cxxflags)
LOCAL_CPP_FEATURES := rtti exceptions
LOCAL_EXPORT_C_INCLUDES := $(llvm_libc++_export_includes)
LOCAL_EXPORT_CPPFLAGS := $(llvm_libc++_export_cxxflags)
LOCAL_STATIC_LIBRARIES := android_support

# For armeabi's shared version of libc++ compiled by clang, we need compiler-rt or libatomic
# for __atomic_fetch_add_4.  Note that "clang -gcc-toolchain" uses gcc4.8's as/ld/libs, including
# libatomic (which is not available in gcc4.6)
#
# On the other hand, all prebuilt libc++ libaries at sources/cxx-stl/llvm-libc++/libs are
# compiled with "clang -gcc-toolchain *4.8*" with -latomic, such that uses of prebuilt
# libc++_shared.so don't automatically requires -latomic or compiler-rt, unless code does
# "#include <atomic>" where  __atomic_is_lock_free is needed for armeabi and mips
#
ifeq ($(TARGET_ARCH_ABI),armeabi)
ifneq (,$(filter clang%,$(NDK_TOOLCHAIN_VERSION)))
LOCAL_SHARED_LIBRARIES := compiler_rt_shared
endif
endif

include $(BUILD_SHARED_LIBRARY)

endif # LIBCXX_FORCE_REBUILD == true

$(call import-module, android/support)
$(call import-module, android/compiler-rt)
