package com.example.demo

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.example.demo.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.tvTitle.text = getString(R.string.app_name)
        binding.tvSubtitle.text = getString(R.string.build_info, BuildConfig.VERSION_NAME, BuildConfig.VERSION_CODE)
        binding.btnHello.setOnClickListener {
            binding.tvResult.text = getString(R.string.hello_message)
        }
    }
}
