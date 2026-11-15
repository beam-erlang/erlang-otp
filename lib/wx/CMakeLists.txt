# wx application sources, generation and release rules.
otp_application_version(wx _version)

set(_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/src/wx.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/wx_object.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/wxe_master.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/wxe_server.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/wxe_util.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxAcceleratorEntry.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxAcceleratorTable.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxActivateEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxArtProvider.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxAuiDockArt.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxAuiManager.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxAuiManagerEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxAuiNotebook.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxAuiNotebookEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxAuiPaneInfo.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxAuiSimpleTabArt.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxAuiTabArt.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxBitmap.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxBitmapButton.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxBitmapDataObject.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxBookCtrlBase.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxBookCtrlEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxBoxSizer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxBrush.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxBufferedDC.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxBufferedPaintDC.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxButton.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxCalendarCtrl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxCalendarDateAttr.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxCalendarEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxCaret.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxCheckBox.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxCheckListBox.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxChildFocusEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxChoice.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxChoicebook.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxClientDC.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxClipboard.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxClipboardTextEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxCloseEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxColourData.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxColourDialog.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxColourPickerCtrl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxColourPickerEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxComboBox.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxCommandEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxContextMenuEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxControl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxControlWithItems.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxCursor.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxDC.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxDCOverlay.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxDataObject.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxDateEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxDatePickerCtrl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxDialog.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxDirDialog.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxDirPickerCtrl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxDisplay.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxDisplayChangedEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxDropFilesEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxEraseEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxEvtHandler.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxFileDataObject.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxFileDialog.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxFileDirPickerEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxFilePickerCtrl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxFindReplaceData.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxFindReplaceDialog.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxFlexGridSizer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxFocusEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxFont.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxFontData.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxFontDialog.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxFontPickerCtrl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxFontPickerEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxFrame.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGBSizerItem.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGCDC.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGLCanvas.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGLContext.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGauge.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGenericDirCtrl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGraphicsBrush.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGraphicsContext.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGraphicsFont.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGraphicsGradientStops.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGraphicsMatrix.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGraphicsObject.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGraphicsPath.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGraphicsPen.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGraphicsRenderer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGrid.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGridBagSizer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGridCellAttr.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGridCellBoolEditor.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGridCellBoolRenderer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGridCellChoiceEditor.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGridCellEditor.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGridCellFloatEditor.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGridCellFloatRenderer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGridCellNumberEditor.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGridCellNumberRenderer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGridCellRenderer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGridCellStringRenderer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGridCellTextEditor.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGridEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxGridSizer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxHelpEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxHtmlEasyPrinting.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxHtmlLinkEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxHtmlWindow.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxIcon.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxIconBundle.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxIconizeEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxIdleEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxImage.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxImageList.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxInitDialogEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxJoystickEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxKeyEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxLayoutAlgorithm.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxListBox.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxListCtrl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxListEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxListItem.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxListItemAttr.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxListView.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxListbook.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxLocale.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxLogNull.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMDIChildFrame.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMDIClientWindow.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMDIParentFrame.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMask.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMaximizeEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMemoryDC.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMenu.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMenuBar.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMenuEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMenuItem.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMessageDialog.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMiniFrame.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMirrorDC.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMouseCaptureChangedEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMouseCaptureLostEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMouseEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMoveEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxMultiChoiceDialog.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxNavigationKeyEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxNotebook.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxNotificationMessage.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxNotifyEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxOverlay.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPageSetupDialog.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPageSetupDialogData.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPaintDC.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPaintEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPalette.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPaletteChangedEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPanel.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPasswordEntryDialog.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPen.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPickerBase.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPopupTransientWindow.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPopupWindow.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPostScriptDC.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPreviewCanvas.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPreviewControlBar.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPreviewFrame.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPrintData.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPrintDialog.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPrintDialogData.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPrintPreview.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPrinter.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxPrintout.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxProgressDialog.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxQueryNewPaletteEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxRadioBox.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxRadioButton.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxRegion.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSashEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSashLayoutWindow.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSashWindow.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxScreenDC.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxScrollBar.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxScrollEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxScrollWinEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxScrolledWindow.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSetCursorEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxShowEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSingleChoiceDialog.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSizeEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSizer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSizerFlags.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSizerItem.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSlider.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSpinButton.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSpinCtrl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSpinEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSplashScreen.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSplitterEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSplitterWindow.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxStaticBitmap.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxStaticBox.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxStaticBoxSizer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxStaticLine.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxStaticText.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxStatusBar.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxStdDialogButtonSizer.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxStyledTextCtrl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxStyledTextEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSysColourChangedEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSystemOptions.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxSystemSettings.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxTaskBarIcon.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxTaskBarIconEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxTextAttr.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxTextCtrl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxTextDataObject.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxTextEntryDialog.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxToggleButton.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxToolBar.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxToolTip.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxToolbook.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxTopLevelWindow.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxTreeCtrl.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxTreeEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxTreebook.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxUpdateUIEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxWebView.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxWebViewEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxWindow.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxWindowCreateEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxWindowDC.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxWindowDestroyEvent.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxXmlResource.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wx_misc.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/glu.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/gl.erl"
)

include("${PROJECT_SOURCE_DIR}/cmake/WxConfiguration.cmake")
set(_wx_general
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/wxe_nif.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/wxe_ps_init.c"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/wxe_main.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/wxe_impl.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/wxe_helpers.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/wxe_callback_impl.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/wxe_return.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/wxe_gl.cpp"
)
set(_wx_generated
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/gen/wxe_wrapper_1.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/gen/wxe_wrapper_2.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/gen/wxe_wrapper_3.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/gen/wxe_wrapper_4.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/gen/wxe_wrapper_5.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/gen/wxe_wrapper_6.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/gen/wxe_wrapper_7.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/gen/wxe_wrapper_8.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/gen/wxe_events.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/gen/wxe_init.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/gen/wxe_func_table.cpp"
)
set(_wx_opengl
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/gen/gl_nif.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/gen/glu_nif.cpp"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/egl_impl.c"
)
set(_wx_headers
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/wxe_nif.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/wxe_callback_impl.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/wxe_events.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/wxe_gl.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/wxe_helpers.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/wxe_impl.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/wxe_memory.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/wxe_return.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/egl_impl.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/gen/wxe_macros.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/gen/wxe_derived_dest.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/gen/gl_finit.h"
    "${CMAKE_CURRENT_SOURCE_DIR}/c_src/gen/gl_fdefs.h"
)
otp_add_compile_job(TARGET otp_wx_examples_demo APP wx
    OUT "${OTP_GENERATED_ROOT}/wx/examples/demo"
    GENERATED "${OTP_GENERATED_ROOT}/wx/examples/demo"
    OPTIONS warnings_as_errors warn_missing_doc_function warn_missing_doc_callback
        warn_missing_spec_documented nowarn_missing_doc nowarn_missing_spec_documented nowarn_deprecated_catch
    PATHS "${OTP_BOOTSTRAP_ROOT}/lib/wx/ebin"
    SOURCES
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/demo.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/demo_html_tagger.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_aui.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_button.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_canvas.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_canvas_paint.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_choices.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_cursor.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_dialogs.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_frame_utils.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_gauge.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_gl.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_grid.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_htmlWindow.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_listCtrl.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_notebook.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_notificationMessage.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_pickers.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_popupMenu.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_radioBox.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_sashWindow.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_sizers.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_slider.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_splitterWindow.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_static.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_textCtrl.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_treeCtrl.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_graphicsContext.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_webview.erl"
    DEPENDS otp_bootstrap_wx
)
otp_add_compile_job(TARGET otp_wx_examples_sudoku APP wx
    OUT "${OTP_GENERATED_ROOT}/wx/examples/sudoku"
    GENERATED "${OTP_GENERATED_ROOT}/wx/examples/sudoku"
    OPTIONS warnings_as_errors warn_missing_doc_function warn_missing_doc_callback
        warn_missing_spec_documented nowarn_missing_doc nowarn_missing_spec_documented nowarn_deprecated_catch
    PATHS "${OTP_BOOTSTRAP_ROOT}/lib/wx/ebin"
    SOURCES
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/sudoku/sudoku.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/sudoku/sudoku_board.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/sudoku/sudoku_game.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/sudoku/sudoku_gui.erl"
    DEPENDS otp_bootstrap_wx "${CMAKE_CURRENT_SOURCE_DIR}/examples/sudoku/sudoku.hrl"
)
otp_add_compile_job(TARGET otp_wx_examples_simple APP wx
    OUT "${OTP_INTERNAL_ROOT}/wx/examples/simple"
    GENERATED "${OTP_INTERNAL_ROOT}/wx/examples/simple"
    OPTIONS warnings_as_errors warn_missing_doc_function warn_missing_doc_callback
        warn_missing_spec_documented nowarn_missing_doc nowarn_missing_spec_documented
    PATHS "${OTP_BOOTSTRAP_ROOT}/lib/wx/ebin"
    SOURCES
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/simple/hello.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/simple/hello2.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/simple/minimal.erl"
        "${CMAKE_CURRENT_SOURCE_DIR}/examples/simple/menu.erl"
    DEPENDS otp_bootstrap_wx
)
set(_release_sources
    "${CMAKE_CURRENT_SOURCE_DIR}/priv/erlang-logo32.png"
    "${CMAKE_CURRENT_SOURCE_DIR}/priv/erlang-logo64.png"
    "${CMAKE_CURRENT_SOURCE_DIR}/priv/erlang-logo128.png"
    "${CMAKE_CURRENT_SOURCE_DIR}/src/gen/wxe_funcs.hrl"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/demo.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/demo.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/demo_html_tagger.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/demo_html_tagger.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_aui.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_aui.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_button.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_button.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_canvas.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_canvas.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_canvas_paint.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_canvas_paint.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_choices.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_choices.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_cursor.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_cursor.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_dialogs.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_dialogs.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_frame_utils.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_frame_utils.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_gauge.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_gauge.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_gl.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_gl.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_grid.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_grid.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_htmlWindow.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_htmlWindow.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_listCtrl.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_listCtrl.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_notebook.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_notebook.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_notificationMessage.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_notificationMessage.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_pickers.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_pickers.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_popupMenu.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_popupMenu.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_radioBox.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_radioBox.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_sashWindow.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_sashWindow.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_sizers.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_sizers.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_slider.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_slider.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_splitterWindow.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_splitterWindow.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_static.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_static.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_textCtrl.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_textCtrl.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_treeCtrl.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_treeCtrl.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_graphicsContext.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_graphicsContext.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_webview.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/demo/ex_webview.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/sudoku/sudoku.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/sudoku/sudoku.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/sudoku/sudoku_board.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/sudoku/sudoku_board.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/sudoku/sudoku_game.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/sudoku/sudoku_game.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/sudoku/sudoku_gui.erl"
    "${OTP_GENERATED_ROOT}/wx/examples/sudoku/sudoku_gui.beam"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/simple/hello.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/simple/hello2.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/simple/minimal.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/simple/menu.erl"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/image.jpg"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/erlang.png"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/demo/ex_htmlWindow.html"
    "${CMAKE_CURRENT_SOURCE_DIR}/examples/sudoku/sudoku.hrl"
)
set(_release_executables)
set(_release_outputs)
foreach(_source IN LISTS _release_sources)
    if(_source MATCHES "^${OTP_GENERATED_ROOT}/")
        file(RELATIVE_PATH _relative "${OTP_GENERATED_ROOT}/wx" "${_source}")
    else()
        file(RELATIVE_PATH _relative "${CMAKE_CURRENT_SOURCE_DIR}" "${_source}")
    endif()
    if(_relative MATCHES "^examples/")
        set(_relative "doc/${_relative}")
    endif()
    set(_output "${PROJECT_BINARY_DIR}/lib/wx/${_relative}")
    if(_source IN_LIST _release_executables)
        set(_mode 755)
    else()
        set(_mode 644)
    endif()
    get_filename_component(_output_directory "${_output}" DIRECTORY)
    otp_cmake_literal(_source_literal "${_source}")
    otp_cmake_literal(_output_literal "${_output}")
    otp_cmake_literal(_directory_literal "${_output_directory}")
    set(_permissions OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ)
    if(_mode EQUAL 755)
        list(APPEND _permissions OWNER_EXECUTE GROUP_EXECUTE WORLD_EXECUTE)
    endif()
    string(JOIN " " _permissions ${_permissions})
    string(SHA256 _copy_id "${_source};${_output};${_mode}")
    set(_copy_script "${OTP_INTERNAL_ROOT}/wx/assets/${_copy_id}.cmake")
    file(GENERATE OUTPUT "${_copy_script}" CONTENT
        "file(MAKE_DIRECTORY ${_directory_literal})\nfile(COPY_FILE ${_source_literal} ${_output_literal})\nfile(CHMOD ${_output_literal} PERMISSIONS ${_permissions})\n")
    add_custom_command(OUTPUT "${_output}"
        COMMAND "${CMAKE_COMMAND}" -P "${_copy_script}"
        DEPENDS "${_source}" "${_copy_script}"
        VERBATIM
    )
    list(APPEND _release_outputs "${_output}")
    get_filename_component(_directory "${_relative}" DIRECTORY)
    if(_source IN_LIST _release_executables)
        install(PROGRAMS "${_output}" DESTINATION "lib/wx-${_version}/${_directory}")
    else()
        install(FILES "${_output}" DESTINATION "lib/wx-${_version}/${_directory}")
    endif()
endforeach()
add_custom_target(otp_wx_assets ALL DEPENDS ${_release_outputs})
add_dependencies(otp_wx_assets otp_wx_examples_simple)
set_property(GLOBAL APPEND PROPERTY OTP_STAGED_RESOURCE_OUTPUTS ${_release_outputs})

# The application resource enumerates the checked-in generated Erlang wrappers.
set(_generated_modules "")
foreach(_source IN LISTS _sources)
    if(_source MATCHES "/src/gen/[^/]+[.]erl$")
        get_filename_component(_module "${_source}" NAME_WE)
        string(APPEND _generated_modules "${_module},\n    ")
    endif()
endforeach()

file(GLOB_RECURSE _headers CONFIGURE_DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/src/*.hrl" "${CMAKE_CURRENT_SOURCE_DIR}/include/*.hrl")
otp_add_application(
    APP wx
    SOURCES ${_sources}
    OPTIONS
        "{d,'CAN_BUILD_DRIVER'}"
        "warn_unused_vars"
        "nowarn_missing_doc"
        "warn_obsolete_bool_op"
        "nowarn_deprecated_catch"
    DEPENDS otp_wxe_driver otp_erl_gl
    INPUTS ${_headers}
    PRESERVE_SOURCE_LAYOUT
    SUBSTITUTIONS "%GEN_MODS%" "${_generated_modules}"
)


set(_wx_native_debug FALSE)
if(CMAKE_BUILD_TYPE STREQUAL "Debug" OR OTP_WX_FORCED_DEBUG)
    set(_wx_native_debug TRUE)
endif()

if(MSVC)
    set(_wx_generated_options /bigobj)
elseif(_wx_native_debug)
    set(_wx_generated_options)
else()
    set(_wx_generated_options -O1)
endif()

if(NOT MSVC AND NOT _wx_native_debug)
foreach(_flag IN ITEMS -fno-move-loop-invariants -fno-var-tracking-assignments)
    string(MAKE_C_IDENTIFIER "${_flag}" _flag_name)
    check_cxx_compiler_flag("${_flag}" OTP_WX_ACCEPTS_${_flag_name})

    if(OTP_WX_ACCEPTS_${_flag_name})
        list(APPEND _wx_generated_options "${_flag}")
    endif()
endforeach()
endif()

foreach(_source IN LISTS _wx_generated _wx_opengl)
    if(_source MATCHES "/gen/.*[.]cpp$")
        set_source_files_properties("${_source}" PROPERTIES
            COMPILE_OPTIONS "${_wx_generated_options}"
        )
    endif()
endforeach()

if(APPLE)
    set_source_files_properties("${PROJECT_SOURCE_DIR}/lib/wx/c_src/wxe_ps_init.c" PROPERTIES
        LANGUAGE OBJC
    )
endif()

otp_application_version(wx OTP_WX_VERSION)
add_library(otp_wxe_driver MODULE ${_wx_general} ${_wx_generated} ${_wx_headers})
add_library(otp_erl_gl MODULE ${_wx_opengl} ${_wx_headers})
target_link_libraries(otp_wxe_driver PRIVATE ${_wx_resolved_link_items})
target_link_libraries(otp_erl_gl PRIVATE ${_wx_gl_libraries} ${CMAKE_DL_LIBS})

if(NOT APPLE AND OTP_WX_GLIB_FOUND)
    target_link_libraries(otp_wxe_driver PRIVATE PkgConfig::OTP_WX_GLIB)
endif()

set(OTP_WX_TARGETS otp_wxe_driver otp_erl_gl)

foreach(_target IN LISTS OTP_WX_TARGETS)
    target_link_libraries(${_target} PRIVATE BEAM::NIF otp_native_config)
    otp_linux_native_flags(${_target})
    target_include_directories(${_target} PRIVATE "${PROJECT_SOURCE_DIR}/lib/wx/c_src")
    target_compile_definitions(${_target} PRIVATE ${_wx_definitions})

    if(_wx_native_debug)
        target_compile_definitions(${_target} PRIVATE DEBUG)
    endif()

    # The native callback path catches C++ exceptions; do not inherit a
    # no-exceptions policy from another product or an ARM branch-protection
    # setting that breaks those catches on Darwin (pinned configure exception).
    if(MSVC)
        target_compile_options(${_target} PRIVATE /W3 /EHsc /bigobj)
        target_link_libraries(${_target} PRIVATE wx::base)
    else()
    target_compile_options(${_target} PRIVATE
        -Wall
        -Wno-deprecated-declarations
        -Werror=return-type
        "$<$<COMPILE_LANGUAGE:CXX>:-fexceptions>"
        "$<$<COMPILE_LANGUAGE:C,OBJC>:${_wx_c_options}>"
        "$<$<COMPILE_LANGUAGE:CXX>:${_wx_cxx_options}>"
    )
    if(DEFINED OTP_LINUX_NATIVE_CFLAGS)
        # configure leaves ordinary Linux wx sources unoptimized; only the
        # generated Release C++ sources receive the separate -O1 recipe.
        target_compile_options(${_target} PRIVATE -O0)
        if(_wx_native_debug)
            target_compile_options(${_target} PRIVATE -g)
        endif()
    else()
        target_compile_options(${_target} PRIVATE -g)
    endif()
    endif()

    if(APPLE AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64)$")
        target_compile_options(${_target} PRIVATE -mbranch-protection=none)
    elseif(NOT APPLE AND NOT MSVC AND NOT _wx_native_debug)
        target_compile_options(${_target} PRIVATE -fomit-frame-pointer)
    endif()

    if(_target STREQUAL otp_wxe_driver)
        set(_name wxe_driver)
    else()
        set(_name erl_gl)
    endif()

    set_target_properties(${_target} PROPERTIES
        PREFIX ""
        OUTPUT_NAME "${_name}"
        LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib/wx/priv/${OTP_TARGET}"
        RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib/wx/priv/${OTP_TARGET}"
        INSTALL_RPATH_USE_LINK_PATH TRUE
    )
    if(NOT WIN32)
        set_target_properties(${_target} PROPERTIES SUFFIX ".so")
    endif()
endforeach()
if(WIN32)
    target_sources(otp_wxe_driver PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/c_src/wxe_win32.rc")
endif()

install(TARGETS ${OTP_WX_TARGETS}
    LIBRARY DESTINATION "lib/wx-${OTP_WX_VERSION}/priv"
    PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE
    RUNTIME DESTINATION "lib/wx-${OTP_WX_VERSION}/priv"
    PERMISSIONS
        OWNER_READ OWNER_WRITE OWNER_EXECUTE
        GROUP_READ GROUP_EXECUTE
        WORLD_READ WORLD_EXECUTE
)
message(STATUS
    "OTP wx: wxWidgets ${OTP_WX_VERSION_FULL} (${OTP_WX_SELECTED_CONFIG}), WebView=${OTP_WX_HAS_WEBVIEW}, selector=${OTP_WX_CONFIG}"
)
