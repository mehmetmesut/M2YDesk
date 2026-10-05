//! M2YDesk: danışan ekranında, danışman bağlıyken görünen kırmızı ekran kenarı çerçevesi.
//!
//! Katmanlı (layered), tıklanmayan (transparent), her zaman üstte, etkinleştirilmeyen bir pencere;
//! yalnızca kenar halkası görünür (pencere bölgesi dış dikdörtgen eksi iç dikdörtgendir).
//! Ekran yakalamadan hariç tutulur (`WDA_EXCLUDEFROMCAPTURE`), böylece danışmanın görüntüsüne girmez.
//! Bağlantı yöneticisi (cm) sürecinde, kullanıcı oturumunda çalışır.

use std::{
    mem::zeroed,
    ptr::{null, null_mut},
    sync::{mpsc, Mutex, Once},
    thread::JoinHandle,
};
use winapi::{
    shared::{
        minwindef::{BOOL, DWORD, LPARAM, LRESULT, UINT, WPARAM},
        windef::{HWND, HWND__},
    },
    um::{
        libloaderapi::{GetModuleHandleW, GetProcAddress, LoadLibraryW},
        wingdi::{CombineRgn, CreateRectRgn, CreateSolidBrush, DeleteObject, RGB, RGN_DIFF},
        winuser::{
            CreateWindowExW, DefWindowProcW, DispatchMessageW, GetMessageW, GetSystemMetrics,
            KillTimer, PostMessageW, PostQuitMessage, RegisterClassW, SetLayeredWindowAttributes,
            SetTimer, SetWindowPos, SetWindowRgn, TranslateMessage, HWND_TOPMOST, LWA_ALPHA, MSG,
            SM_CXVIRTUALSCREEN, SM_CYVIRTUALSCREEN, SM_XVIRTUALSCREEN, SM_YVIRTUALSCREEN,
            SWP_NOACTIVATE, SWP_SHOWWINDOW, WM_CLOSE, WM_DESTROY, WM_DISPLAYCHANGE, WM_TIMER,
            WNDCLASSW, WS_EX_LAYERED, WS_EX_NOACTIVATE, WS_EX_TOOLWINDOW, WS_EX_TOPMOST,
            WS_EX_TRANSPARENT, WS_POPUP,
        },
    },
};

const FRAME_THICKNESS: i32 = 5;
const WDA_EXCLUDEFROMCAPTURE: DWORD = 0x11;
const TIMER_ID: usize = 1;
const TOPMOST_REFRESH_MS: UINT = 2000;
const CLASS_NAME: &str = "M2YDeskKenarCercevesi";

struct Running {
    hwnd: isize,
    thread: JoinHandle<()>,
}

static RUNNING: Mutex<Option<Running>> = Mutex::new(None);
static REGISTER: Once = Once::new();

fn wide(s: &str) -> Vec<u16> {
    s.encode_utf16().chain(std::iter::once(0)).collect()
}

/// Çerçeveyi gösterir ya da kaldırır (tekrarlı çağrılar zararsızdır).
pub fn set_visible(visible: bool) {
    let mut guard = match RUNNING.lock() {
        Ok(g) => g,
        Err(e) => e.into_inner(),
    };
    if visible {
        if guard.is_some() {
            return;
        }
        let (tx, rx) = mpsc::channel::<isize>();
        let thread = std::thread::spawn(move || unsafe { run_window(tx) });
        match rx.recv() {
            Ok(hwnd) if hwnd != 0 => *guard = Some(Running { hwnd, thread }),
            _ => {
                let _ = thread.join();
                log::warn!("M2YDesk: kenar çerçevesi penceresi oluşturulamadı");
            }
        }
    } else if let Some(r) = guard.take() {
        unsafe {
            PostMessageW(r.hwnd as HWND, WM_CLOSE, 0, 0);
        }
        let _ = r.thread.join();
    }
}

/// Pencereyi oluşturur, hwnd'yi bildirir ve iletim döngüsünü çalıştırır.
unsafe fn run_window(tx: mpsc::Sender<isize>) {
    let hinst = GetModuleHandleW(null());
    let class = wide(CLASS_NAME);
    REGISTER.call_once(|| {
        let wc = WNDCLASSW {
            style: 0,
            lpfnWndProc: Some(wnd_proc),
            cbClsExtra: 0,
            cbWndExtra: 0,
            hInstance: hinst,
            hIcon: null_mut(),
            hCursor: null_mut(),
            hbrBackground: CreateSolidBrush(RGB(220, 38, 38)),
            lpszMenuName: null(),
            lpszClassName: class.as_ptr(),
        };
        RegisterClassW(&wc);
    });
    let title = wide("M2YDesk bağlantı çerçevesi");
    let hwnd = CreateWindowExW(
        WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
        class.as_ptr(),
        title.as_ptr(),
        WS_POPUP,
        0,
        0,
        0,
        0,
        null_mut(),
        null_mut(),
        hinst,
        null_mut(),
    );
    if hwnd.is_null() {
        let _ = tx.send(0);
        return;
    }
    SetLayeredWindowAttributes(hwnd, 0, 235, LWA_ALPHA);
    exclude_from_capture(hwnd);
    apply_geometry(hwnd);
    SetTimer(hwnd, TIMER_ID, TOPMOST_REFRESH_MS, None);
    let _ = tx.send(hwnd as isize);

    let mut msg: MSG = zeroed();
    while GetMessageW(&mut msg, null_mut(), 0, 0) > 0 {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }
}

unsafe extern "system" fn wnd_proc(
    hwnd: HWND,
    msg: UINT,
    wparam: WPARAM,
    lparam: LPARAM,
) -> LRESULT {
    match msg {
        WM_CLOSE => {
            KillTimer(hwnd, TIMER_ID);
            winapi::um::winuser::DestroyWindow(hwnd);
            0
        }
        WM_DESTROY => {
            PostQuitMessage(0);
            0
        }
        WM_DISPLAYCHANGE | WM_TIMER => {
            apply_geometry(hwnd);
            0
        }
        _ => DefWindowProcW(hwnd, msg, wparam, lparam),
    }
}

/// Tüm sanal masaüstünü kaplar; görünür bölge yalnızca kenar halkasıdır.
unsafe fn apply_geometry(hwnd: HWND) {
    let x = GetSystemMetrics(SM_XVIRTUALSCREEN);
    let y = GetSystemMetrics(SM_YVIRTUALSCREEN);
    let w = GetSystemMetrics(SM_CXVIRTUALSCREEN);
    let h = GetSystemMetrics(SM_CYVIRTUALSCREEN);
    if w <= 2 * FRAME_THICKNESS || h <= 2 * FRAME_THICKNESS {
        return;
    }
    SetWindowPos(hwnd, HWND_TOPMOST, x, y, w, h, SWP_NOACTIVATE | SWP_SHOWWINDOW);
    let outer = CreateRectRgn(0, 0, w, h);
    let inner = CreateRectRgn(
        FRAME_THICKNESS,
        FRAME_THICKNESS,
        w - FRAME_THICKNESS,
        h - FRAME_THICKNESS,
    );
    CombineRgn(outer, outer, inner, RGN_DIFF);
    DeleteObject(inner as _);
    // Bölgenin sahipliği pencereye geçer; ayrıca silinmez.
    SetWindowRgn(hwnd, outer, 1);
}

/// `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)` — eski Windows'ta yoksa sessizce atlanır.
unsafe fn exclude_from_capture(hwnd: HWND) {
    type SetAffinity = unsafe extern "system" fn(*mut HWND__, DWORD) -> BOOL;
    let lib = LoadLibraryW(wide("user32.dll").as_ptr());
    if lib.is_null() {
        return;
    }
    let p = GetProcAddress(lib, b"SetWindowDisplayAffinity\0".as_ptr() as *const _);
    if p.is_null() {
        return;
    }
    let f: SetAffinity = std::mem::transmute(p);
    f(hwnd, WDA_EXCLUDEFROMCAPTURE);
}
