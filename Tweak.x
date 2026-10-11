// DualBT - vá runtime ham kiem tra chip ho tro Wireless Splitter (Audio Sharing)
// trong bluetoothd, de moi thiet bi Bluetooth deu duoc coi la "ho tro".
// Dia chi duoi day duoc do ngay tren file bluetoothd that cua may ban,
// nen chi dung duoc tren dung ban build do. Neu Apple cap nhat bluetoothd,
// phai do lai va doi hang so VA_PATCH_OFF duoi day.
#import <Foundation/Foundation.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include <sys/mman.h>
#include <string.h>
#include <unistd.h>
#include <libkern/OSCacheControl.h>

// Offset tinh tu dau anh (VA - 0x100000000), lay tu dia chi do duoc:
//   cmp w28,#7      @ 0x1002838a4  -> offset 0x2838a4
//   b.hi ...        @ 0x1002838a8  -> offset 0x2838a8
static const uint64_t PATCH_OFF_1 = 0x2838a4ULL; // -> NOP
static const uint64_t PATCH_OFF_2 = 0x2838a8ULL; // -> B case0 (luon "ho tro")

static void PatchOne(uint64_t base, uint64_t off, uint32_t newWord) {
    uint64_t addr = base + off;
    vm_address_t page = addr & ~(vm_address_t)(getpagesize() - 1);
    size_t pageLen = (size_t)getpagesize() * 2; // phong truong hop vuot trang
    kern_return_t kr = vm_protect(mach_task_self(), page, pageLen, FALSE,
                                   VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        NSLog(@"[DualBT] vm_protect fail %#llx kr=%d", addr, kr);
        return;
    }
    uint32_t *p = (uint32_t *)(uintptr_t)addr;
    uint32_t old = *p;
    *p = newWord;
    sys_icache_invalidate((void *)p, 4);
    vm_protect(mach_task_self(), page, pageLen, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    NSLog(@"[DualBT] patched %#llx: %#x -> %#x", addr, old, newWord);
}

static void DoPatch(void) {
    if (strcmp(getprogname(), "bluetoothd") != 0) return;
    uint32_t n = _dyld_image_count();
    for (uint32_t i = 0; i < n; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name || !strstr(name, "/bluetoothd")) continue;
        uint64_t slide = (uint64_t)_dyld_get_image_vmaddr_slide(i);
        uint64_t base = 0x100000000ULL + slide; // dia chi VA goc + slide ASLR
        PatchOne(base, PATCH_OFF_1, 0xD503201F);   // NOP
        PatchOne(base, PATCH_OFF_2, 0x14000007);   // B #case0 (luon coi la ho tro chip)
        return;
    }
    NSLog(@"[DualBT] khong tim thay anh bluetoothd trong dyld image list");
}

%ctor {
    @autoreleasepool {
        NSLog(@"[DualBT] loaded in %s pid=%d", getprogname(), getpid());
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ DoPatch(); });
    }
}
