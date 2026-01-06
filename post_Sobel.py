import cv2
import numpy as np
import os 
from PIL import Image
import sys



#INPUT_HEX_FILE = "output_image_640x480.hex" 


#OUTPUT_IMAGE_FILE = "result_image.bmp"


WIDTH = 640
HEIGHT = 480

def convert_hex_to_image(hex_path, image_path, width, height):
    
    # 1. ตรวจสอบว่าไฟล์ Input มีอยู่จริงหรือไม่
    if not os.path.exists(hex_path):
        print(f"Error: ไม่พบไฟล์ '{hex_path}' กรุณาตรวจสอบว่า Simulation เสร็จสมบูรณ์แล้ว")
        return

    try:
        # 2. สร้าง Array ว่างๆ ด้วย NumPy เพื่อเก็บข้อมูลพิกเซล
        # เราสร้างเป็นภาพ Grayscale (1 channel) ด้วยชนิดข้อมูล uint8 (0-255)
        image_data = np.zeros((height, width), dtype=np.uint8)

        print(f"กำลังอ่านข้อมูลจาก '{hex_path}'...")
        
        # 3. เปิดไฟล์ .hex เพื่ออ่านข้อมูล
        with open(hex_path, 'r') as f:
            lines = f.readlines()
        
        # ตรวจสอบจำนวนบรรทัดที่อ่านได้ (อาจไม่ตรงเป๊ะก็ได้)
        num_pixels_read = len(lines)
        if num_pixels_read < width * height:
            print(f"คำเตือน: อ่านข้อมูลได้ {num_pixels_read} พิกเซล ซึ่งน้อยกว่าที่คาดไว้ ({width * height})")
        
        # 4. วน Loop เพื่ออ่านค่าพิกเซลจากแต่ละบรรทัดและใส่ลงใน Array
        pixel_index = 0
        for y in range(height):
            for x in range(width):
                if pixel_index < num_pixels_read:
                    # อ่านค่า hex, ลบช่องว่าง/การขึ้นบรรทัดใหม่, แล้วแปลงเป็นเลขฐาน 10
                    try:
                        hex_value = lines[pixel_index].strip()
                        pixel_value = int(hex_value, 16)
                        image_data[y, x] = pixel_value
                    except ValueError:
                        print(f"คำเตือน: ข้อมูลในบรรทัดที่ {pixel_index + 1} ('{hex_value}') ไม่ใช่เลขฐาน 16 ที่ถูกต้อง, จะใช้ค่า 0 แทน")
                        image_data[y, x] = 0

                pixel_index += 1

        # 5. ใช้ OpenCV เพื่อบันทึก Array ข้อมูลภาพลงเป็นไฟล์ .bmp
        # OpenCV จะจัดการเรื่อง Header และการจัดรูปแบบไฟล์ .bmp ให้เองทั้งหมด
        cv2.imwrite(image_path, image_data)
        
        print(f"สำเร็จ! ได้สร้างไฟล์ภาพ '{image_path}' เรียบร้อยแล้ว")

    except Exception as e:
        print(f"เกิดข้อผิดพลาดระหว่างการทำงาน: {e}")


# --- ส่วนที่ใช้รันสคริปต์ ---
if __name__ == "__main__":

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    width = int(sys.argv[3])
    height = int(sys.argv[4])
    
    convert_hex_to_image(input_file, output_file, width, height)