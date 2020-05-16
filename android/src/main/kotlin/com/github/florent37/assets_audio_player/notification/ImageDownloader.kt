package com.github.florent37.assets_audio_player.notification

import android.content.Context
import android.graphics.Bitmap
import android.graphics.drawable.Drawable
import android.net.Uri
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.CustomTarget
import com.bumptech.glide.request.transition.Transition
import io.flutter.embedding.engine.loader.FlutterLoader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine

object ImageDownloader {

    suspend fun getBitmap(context: Context, fileType: String, filePath: String, filePackage: String?): Bitmap = withContext(Dispatchers.IO) {
        suspendCoroutine<Bitmap> { continuation ->
            try {
                when (fileType) {
                    "asset" -> {
                        val path = if(filePackage == null){
                            FlutterLoader.getInstance().getLookupKeyForAsset(filePath)
                        } else {
                            FlutterLoader.getInstance().getLookupKeyForAsset(filePath, filePackage)
                        }
                        Glide.with(context)
                                .asBitmap()
                                .timeout(5000)
                                .load(Uri.parse("file://$path"))
                                .into(object : CustomTarget<Bitmap>() {
                                    override fun onLoadFailed(errorDrawable: Drawable?) {
                                        continuation.resumeWithException(Exception("failed to download $filePath"))
                                    }

                                    override fun onResourceReady(resource: Bitmap, transition: Transition<in Bitmap>?) {
                                        continuation.resume(resource)
                                    }

                                    override fun onLoadCleared(placeholder: Drawable?) {

                                    }
                                })

                        //val istr = context.assets.open("flutter_assets/$filePath")
                        //val bitmap = BitmapFactory.decodeStream(istr)
                        //continuation.resume(bitmap)
                    }
                    "network" -> {
                        Glide.with(context)
                                .asBitmap()
                                .timeout(5000)
                                .load(filePath)
                                .into(object : CustomTarget<Bitmap>() {
                                    override fun onLoadFailed(errorDrawable: Drawable?) {
                                        continuation.resumeWithException(Exception("failed to download $filePath"))
                                    }

                                    override fun onResourceReady(resource: Bitmap, transition: Transition<in Bitmap>?) {
                                        continuation.resume(resource)
                                    }

                                    override fun onLoadCleared(placeholder: Drawable?) {

                                    }
                                })
                    }
                    else -> {
                        //val options = BitmapFactory.Options().apply {
                        //    inPreferredConfig = Bitmap.Config.ARGB_8888
                        //}
                        //val bitmap = BitmapFactory.decodeFile(filePath, options)
                        //continuation.resume(bitmap)

                        Glide.with(context)
                                .asBitmap()
                                .timeout(5000)
                                .load(File(filePath).path)
                                .into(object : CustomTarget<Bitmap>() {
                                    override fun onLoadFailed(errorDrawable: Drawable?) {
                                        continuation.resumeWithException(Exception("failed to download $filePath"))
                                    }

                                    override fun onResourceReady(resource: Bitmap, transition: Transition<in Bitmap>?) {
                                        continuation.resume(resource)
                                    }

                                    override fun onLoadCleared(placeholder: Drawable?) {

                                    }
                                })
                    }
                }
            } catch (t: Throwable) {
                // handle exception
                t.printStackTrace()
                continuation.resumeWithException(t)
            }
        }
    }
}