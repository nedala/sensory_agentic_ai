from PIL import Image
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import landscape, letter
from reportlab.lib import colors
import os

folder = r"C:\Users\XH247\Downloads\screenshots"
output_pdf = "images_with_filenames.pdf"
page_size = landscape(letter)
width, height = page_size
c = canvas.Canvas(output_pdf, pagesize=page_size)

for filename in sorted(os.listdir(folder)):
    if filename.lower().endswith(("jpg", "jpeg", "png", "bmp", "gif")):
        img_path = os.path.join(folder, filename)

        # Draw filename at the top
        c.setFont("Helvetica", 16)
        c.drawString(40, height - 40, f"screenshots/{filename}")

        # Load image
        img = Image.open(img_path)
        img_width, img_height = img.size

        # Fit image to landscape page with margins
        max_w = width - 80
        max_h = height - 120

        scale = min(max_w / img_width, max_h / img_height)

        new_w = img_width * scale
        new_h = img_height * scale

        # Center horizontally, with slight vertical shift for filename
        x = (width - new_w) / 2
        y = (height - new_h) / 2 - 20

        # Draw image
        c.drawImage(img_path, x, y, width=new_w, height=new_h)

        # 🔲 Draw border around the image
        c.setStrokeColor(colors.black)
        c.setLineWidth(2)
        c.rect(x, y, new_w, new_h)

        c.showPage()

c.save()

print("PDF created:", output_pdf)
