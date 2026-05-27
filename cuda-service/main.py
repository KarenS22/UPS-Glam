from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
from PIL import Image, ImageOps
# Disable Pillow decompression bomb limits to support extremely large image files
Image.MAX_IMAGE_PIXELS = None
import io
import base64
import logging
from filters import apply_filter, HAS_CUDA

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("cuda-service")

app = FastAPI(
    title="Instagram PyCUDA Processing Service",
    description="GPU-accelerated image filters using PyCUDA with FastAPI",
    version="1.0.0"
)

@app.get("/health")
def health_check():
    """
    Health check endpoint to verify status and GPU hardware activation.
    """
    return {
        "status": "healthy",
        "gpu_accelerated": HAS_CUDA,
        "device_name": "NVIDIA GPU" if HAS_CUDA else "CPU Fallback (Simulated)"
    }

@app.post("/process")
async def process_image(
    file: UploadFile = File(...),
    filter_type: str = Form("media"),
    kernel_size: str = Form("9x9")
):
    """
    Processes the uploaded image with the requested filter.
    Returns a JSON containing the filtered image encoded in base64 along with GPU metrics.
    """
    valid_filters = ["blur", "sharpen", "sobel", "cartooning", "tricolor", "tricolor_inverted", "recuerdo_historico"]
    if filter_type not in valid_filters:
        raise HTTPException(
            status_code=400, 
            detail=f"Invalid filter type '{filter_type}'. Choose from: {', '.join(valid_filters)}"
        )
        
    try:
        # Read uploaded image bytes
        image_bytes = await file.read()
        
        # Load image via PIL and transpose according to EXIF rotation
        try:
            raw_image = Image.open(io.BytesIO(image_bytes))
            image = ImageOps.exif_transpose(raw_image).convert("RGB")
        except Exception as pil_err:
            logger.warning(f"PIL failed to load image: {pil_err}")
            raise HTTPException(status_code=400, detail="Invalid image file format.")
            
        # Apply filter and get metrics
        processed_img, metrics = apply_filter(image, filter_type, kernel_size)
        
        # Convert filtered image back to bytes
        buffered = io.BytesIO()
        processed_img.save(buffered, format="JPEG")
        processed_bytes = buffered.getvalue()
        
        # Base64 encode
        img_base64 = base64.b64encode(processed_bytes).decode("utf-8")
        
        return JSONResponse(
            status_code=200,
            content={
                "filter_applied": filter_type,
                "image_base64": img_base64,
                "metrics": metrics
            }
        )
        
    except HTTPException as http_ex:
        # Re-raise HTTPExceptions directly to maintain correct status code (like 400)
        raise http_ex
    except Exception as e:
        logger.error(f"Failed to process image: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Image processing failed: {str(e)}")


@app.post("/preview")
async def generate_previews(file: UploadFile = File(...)):
    """
    Generates fast 254x254 thumbnail previews for all filters with a 3x3 kernel.
    Returns a JSON containing a map of filter_type -> base64 encoded thumbnail image.
    """
    try:
        image_bytes = await file.read()
        try:
            raw_image = Image.open(io.BytesIO(image_bytes))
            image = ImageOps.exif_transpose(raw_image).convert("RGB")
        except Exception as pil_err:
            logger.warning(f"PIL failed to load image: {pil_err}")
            raise HTTPException(status_code=400, detail="Invalid image file format.")
            
        # Scale to exactly 254x254 pixels
        image = image.resize((254, 254))
        
        valid_filters = ["blur", "sharpen", "sobel", "cartooning", "tricolor", "tricolor_inverted", "recuerdo_historico"]
        previews = {}
        
        # Add the original scaled image under the 'none' key
        try:
            buffered = io.BytesIO()
            image.save(buffered, format="JPEG")
            previews["none"] = base64.b64encode(buffered.getvalue()).decode("utf-8")
        except Exception as e:
            logger.error(f"Failed to encode original scaled preview: {e}")
            previews["none"] = ""
        
        for filter_type in valid_filters:
            try:
                processed_img, _ = apply_filter(image, filter_type, "3x3")
                buffered = io.BytesIO()
                processed_img.save(buffered, format="JPEG")
                img_base64 = base64.b64encode(buffered.getvalue()).decode("utf-8")
                previews[filter_type] = img_base64
            except Exception as filter_err:
                logger.error(f"Failed to generate preview for '{filter_type}': {filter_err}")
                previews[filter_type] = ""
                
        return JSONResponse(
            status_code=200,
            content={
                "previews": previews
            }
        )
    except Exception as e:
        logger.error(f"Failed to generate image previews: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Preview generation failed: {str(e)}")


if __name__ == "__main__":
    import uvicorn
    import os
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host=host, port=port)
