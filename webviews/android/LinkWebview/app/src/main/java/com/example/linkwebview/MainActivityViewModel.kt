package com.example.linkwebview

import androidx.lifecycle.ViewModel

class MainActivityViewModel : ViewModel() {
    // NOTE: This is an in-memory variable for clarity of code purposes, but should be persisted
    // to disk to handle background memory reclaiming.
    public var linkInitializationUrl : String? = null
}