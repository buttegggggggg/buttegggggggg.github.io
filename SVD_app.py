from PyQt6.QtCore import Qt
from PyQt6.QtGui import QImage, QPixmap

# ---- PyQt6 enum 快捷別名 ----
Align = Qt.AlignmentFlag
Ori = Qt.Orientation
AR = Qt.AspectRatioMode
Trans = Qt.TransformationMode
Fmt = QImage.Format
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QLabel, QPushButton,
    QVBoxLayout, QHBoxLayout, QGroupBox, QFileDialog, QSlider,
    QComboBox, QFormLayout, QMessageBox
)

import sys
import numpy as np
from PIL import Image
import io

class SVDCompressionApp(QMainWindow):

    def __init__(self):
        super().__init__()
        self.setWindowTitle("SVD 智慧影像壓縮工具")
        self.setGeometry(100, 100, 1400, 800)
        
        # 資料儲存
        self.original_image = None
        self.compressed_image = None
        self.original_size_mb = 0
        self.U_R = None
        self.S_R = None
        self.Vt_R = None
        self.U_G = None
        self.S_G = None
        self.Vt_G = None
        self.U_B = None
        self.S_B = None
        self.Vt_B = None
        self.max_rank = 0
        
        self.init_ui()
        
    def init_ui(self):
        # 主要容器
        main_widget = QWidget()
        self.setCentralWidget(main_widget)
        main_layout = QVBoxLayout(main_widget)
        
        # 標題
        title_label = QLabel("SVD 智慧影像壓縮工具")
        title_label.setAlignment(Qt.AlignCenter)
        title_label.setStyleSheet("""
            font-size: 24px;
            font-weight: bold;
            padding: 10px;
            color: #2c3e50;
        """)
        main_layout.addWidget(title_label)
        
        # 上半部：圖片顯示區
        image_layout = QHBoxLayout()
        
        # 左邊：原始圖片
        left_group = self.create_image_group("原始圖片", is_original=True)
        image_layout.addWidget(left_group)
        
        # 右邊：壓縮後圖片
        right_group = self.create_image_group("壓縮後圖片", is_original=False)
        image_layout.addWidget(right_group)
        
        main_layout.addLayout(image_layout)
        
        # 中間：控制區
        control_group = self.create_control_panel()
        main_layout.addWidget(control_group)
        
        # 下方：建議區
        suggestion_group = self.create_suggestion_panel()
        main_layout.addWidget(suggestion_group)
        
    def create_image_group(self, title, is_original):
        """建立圖片顯示區塊"""
        group_box = QGroupBox(title)
        group_box.setStyleSheet("""
            QGroupBox {
                font-size: 16px;
                font-weight: bold;
                border: 2px solid #3498db;
                border-radius: 10px;
                margin-top: 10px;
                padding: 15px;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 10px;
                padding: 0 5px;
            }
        """)
        
        layout = QVBoxLayout()
        
        # 圖片顯示區（可拖放）
        if is_original:
            image_label = QLabel()
            image_label.setMinimumSize(500, 400)
            image_label.setMaximumSize(600, 500)
            image_label.setAlignment(Qt.AlignCenter)
            image_label.setStyleSheet("""
                QLabel {
                    border: 2px dashed #95a5a6;
                    border-radius: 10px;
                    background-color: #ecf0f1;
                }
            """)
            image_label.setText("📁\n\n將圖片拖移到這邊\n或點擊下方按鈕上傳")
            image_label.setScaledContents(False)
            
            # 設定拖放
            image_label.setAcceptDrops(True)
            image_label.dragEnterEvent = self.drag_enter_event
            image_label.dropEvent = self.drop_event
            
            self.original_image_label = image_label
        else:
            image_label = QLabel()
            image_label.setMinimumSize(500, 400)
            image_label.setMaximumSize(600, 500)
            image_label.setAlignment(Qt.AlignCenter)
            image_label.setStyleSheet("""
                QLabel {
                    border: 2px solid #3498db;
                    border-radius: 10px;
                    background-color: #e8f4f8;
                }
            """)
            image_label.setText("壓縮預覽\n\n上傳圖片後\n調整滑桿查看效果")
            image_label.setScaledContents(False)
            self.compressed_image_label = image_label
        
        layout.addWidget(image_label)
        
        # 資訊顯示
        info_layout = QFormLayout()
        
        if is_original:
            self.original_ratio_label = QLabel("？？%")
            self.original_size_label = QLabel("？？ MB")
            info_layout.addRow("目前壓縮比例：", self.original_ratio_label)
            info_layout.addRow("檔案大小：", self.original_size_label)
            
            # 上傳按鈕
            upload_btn = QPushButton("📁 選擇圖片")
            upload_btn.setStyleSheet("""
                QPushButton {
                    background-color: #3498db;
                    color: white;
                    padding: 10px;
                    border-radius: 5px;
                    font-size: 14px;
                    font-weight: bold;
                }
                QPushButton:hover {
                    background-color: #2980b9;
                }
            """)
            upload_btn.clicked.connect(self.upload_image)
            layout.addWidget(upload_btn)
        else:
            self.compressed_ratio_label = QLabel("？？%")
            self.compressed_size_label = QLabel("？？ MB")
            self.compressed_psnr_label = QLabel("？？ dB")
            info_layout.addRow("壓縮比例：", self.compressed_ratio_label)
            info_layout.addRow("壓縮後大小：", self.compressed_size_label)
            info_layout.addRow("品質 (PSNR)：", self.compressed_psnr_label)
            
            # 儲存按鈕
            save_btn = QPushButton("💾 儲存壓縮圖片")
            save_btn.setStyleSheet("""
                QPushButton {
                    background-color: #27ae60;
                    color: white;
                    padding: 10px;
                    border-radius: 5px;
                    font-size: 14px;
                    font-weight: bold;
                }
                QPushButton:hover {
                    background-color: #229954;
                }
            """)
            save_btn.clicked.connect(self.save_compressed_image)
            layout.addWidget(save_btn)
        
        layout.addLayout(info_layout)
        group_box.setLayout(layout)
        
        return group_box
    
    def create_control_panel(self):
        """建立控制面板"""
        group_box = QGroupBox("壓縮控制")
        group_box.setStyleSheet("""
            QGroupBox {
                font-size: 16px;
                font-weight: bold;
                border: 2px solid #e74c3c;
                border-radius: 10px;
                margin-top: 10px;
                padding: 15px;
            }
        """)
        
        layout = QVBoxLayout()
        
        # 預設模板選擇
        template_layout = QHBoxLayout()
        template_label = QLabel("選擇預設模板：")
        template_label.setStyleSheet("font-size: 14px;")
        
        self.template_combo = QComboBox()
        self.template_combo.addItems([
            "自訂",
            "社群媒體 (2 MB, 快速上傳)",
            "郵件附件 (5 MB, 平衡)",
            "高品質存檔 (保持 PSNR > 40 dB)"
        ])
        self.template_combo.currentIndexChanged.connect(self.apply_template)
        
        template_layout.addWidget(template_label)
        template_layout.addWidget(self.template_combo)
        template_layout.addStretch()
        layout.addLayout(template_layout)
        
        # 滑桿 1：壓縮比例
        ratio_layout = QVBoxLayout()
        ratio_label = QLabel("拖動來調整壓縮比例 (保留奇異值比例)")
        ratio_label.setStyleSheet("font-size: 13px; color: #34495e;")
        ratio_layout.addWidget(ratio_label)
        
        ratio_slider_layout = QHBoxLayout()
        self.ratio_slider = QSlider(Qt.Horizontal)
        self.ratio_slider.setMinimum(1)
        self.ratio_slider.setMaximum(100)
        self.ratio_slider.setValue(50)
        self.ratio_slider.setTickPosition(QSlider.TicksBelow)
        self.ratio_slider.setTickInterval(10)
        self.ratio_slider.valueChanged.connect(self.ratio_slider_changed)
        
        self.ratio_value_label = QLabel("50%")
        self.ratio_value_label.setStyleSheet("font-size: 14px; font-weight: bold; color: #e74c3c;")
        self.ratio_value_label.setMinimumWidth(60)
        
        ratio_slider_layout.addWidget(self.ratio_slider)
        ratio_slider_layout.addWidget(self.ratio_value_label)
        ratio_layout.addLayout(ratio_slider_layout)
        
        layout.addLayout(ratio_layout)
        
        # 滑桿 2：目標大小
        size_layout = QVBoxLayout()
        size_label = QLabel("拖動來調整目標檔案大小 (MB)")
        size_label.setStyleSheet("font-size: 13px; color: #34495e;")
        size_layout.addWidget(size_label)
        
        size_slider_layout = QHBoxLayout()
        self.size_slider = QSlider(Qt.Horizontal)
        self.size_slider.setMinimum(1)
        self.size_slider.setMaximum(100)  # 會根據原始圖片大小動態調整
        self.size_slider.setValue(50)
        self.size_slider.setTickPosition(QSlider.TicksBelow)
        self.size_slider.setTickInterval(10)
        self.size_slider.valueChanged.connect(self.size_slider_changed)
        
        self.size_value_label = QLabel("？？ MB")
        self.size_value_label.setStyleSheet("font-size: 14px; font-weight: bold; color: #e74c3c;")
        self.size_value_label.setMinimumWidth(80)
        
        size_slider_layout.addWidget(self.size_slider)
        size_slider_layout.addWidget(self.size_value_label)
        size_layout.addLayout(size_slider_layout)
        
        layout.addLayout(size_layout)
        
        # 說明文字
        note_label = QLabel("💡 註：兩條滑桿會互相連動，拖動任一滑桿都會自動調整另一個")
        note_label.setStyleSheet("font-size: 12px; color: #7f8c8d; font-style: italic;")
        layout.addWidget(note_label)
        
        group_box.setLayout(layout)
        return group_box
    
    def create_suggestion_panel(self):
        """建立建議面板"""
        group_box = QGroupBox("智慧建議 - 基於 Eckart-Young 定理")
        group_box.setStyleSheet("""
            QGroupBox {
                font-size: 16px;
                font-weight: bold;
                border: 2px solid #9b59b6;
                border-radius: 10px;
                margin-top: 10px;
                padding: 15px;
            }
        """)
        
        layout = QHBoxLayout()
        
        # 建議選項 1
        self.suggestion_btn1 = QPushButton("建議 1\n\n社群媒體優化\n壓縮至 2 MB\nPSNR ≈ 35 dB")
        self.suggestion_btn1.setMinimumHeight(100)
        self.suggestion_btn1.clicked.connect(lambda: self.apply_suggestion(1))
        self.style_suggestion_button(self.suggestion_btn1)
        
        # 建議選項 2
        self.suggestion_btn2 = QPushButton("建議 2\n\n平衡模式\n壓縮至 50%\nPSNR ≈ 40 dB")
        self.suggestion_btn2.setMinimumHeight(100)
        self.suggestion_btn2.clicked.connect(lambda: self.apply_suggestion(2))
        self.style_suggestion_button(self.suggestion_btn2)
        
        # 建議選項 3
        self.suggestion_btn3 = QPushButton("建議 3\n\n高品質保存\n壓縮至 80%\nPSNR ≈ 45 dB")
        self.suggestion_btn3.setMinimumHeight(100)
        self.suggestion_btn3.clicked.connect(lambda: self.apply_suggestion(3))
        self.style_suggestion_button(self.suggestion_btn3)
        
        layout.addWidget(self.suggestion_btn1)
        layout.addWidget(self.suggestion_btn2)
        layout.addWidget(self.suggestion_btn3)
        
        group_box.setLayout(layout)
        return group_box
    
    def style_suggestion_button(self, button):
        """設定建議按鈕樣式"""
        button.setStyleSheet("""
            QPushButton {
                background-color: #9b59b6;
                color: white;
                padding: 15px;
                border-radius: 10px;
                font-size: 13px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #8e44ad;
            }
            QPushButton:pressed {
                background-color: #7d3c98;
            }
        """)
    
    # ==================== 拖放功能 ====================
    
    def drag_enter_event(self, event):
        """拖曳進入事件"""
        if event.mimeData().hasUrls():
            event.accept()
        else:
            event.ignore()
    
    def drop_event(self, event):
        """放下檔案事件"""
        files = [u.toLocalFile() for u in event.mimeData().urls()]
        if files:
            self.load_image(files[0])
    
    # ==================== 圖片處理功能 ====================
    
    def upload_image(self):
        """上傳圖片按鈕"""
        file_name, _ = QFileDialog.getOpenFileName(
            self, "選擇圖片", "", "圖片檔案 (*.png *.jpg *.jpeg *.bmp)"
        )
        if file_name:
            self.load_image(file_name)
    
    def load_image(self, file_path):
        """載入圖片並進行 SVD"""
        try:
            # 讀取圖片
            img = Image.open(file_path)
            img_array = np.array(img)
            
            # 儲存原始圖片
            self.original_image = img_array
            
            # 計算檔案大小
            self.original_size_mb = len(img_array.tobytes()) / (1024 * 1024)
            
            # 顯示原始圖片
            self.display_image(self.original_image_label, img_array)
            
            # 更新資訊
            self.original_ratio_label.setText("100%")
            self.original_size_label.setText(f"{self.original_size_mb:.2f} MB")
            
            # 進行 SVD 分解
            self.perform_svd(img_array)
            
            # 更新滑桿最大值
            self.size_slider.setMaximum(int(self.original_size_mb * 100))
            self.size_slider.setValue(int(self.original_size_mb * 50))
            
            # 初始壓縮
            self.update_compression()
            
            QMessageBox.information(self, "成功", "圖片載入成功！")
            
        except Exception as e:
            QMessageBox.critical(self, "錯誤", f"載入圖片失敗：{str(e)}")
    
    def perform_svd(self, img_array):
        """對 RGB 三個通道進行 SVD"""
        if len(img_array.shape) == 2:
            # 灰階圖片
            img_array = np.stack([img_array] * 3, axis=2)
        
        R = img_array[:, :, 0].astype(float)
        G = img_array[:, :, 1].astype(float)
        B = img_array[:, :, 2].astype(float)
        
        # SVD 分解
        self.U_R, self.S_R, self.Vt_R = np.linalg.svd(R, full_matrices=False)
        self.U_G, self.S_G, self.Vt_G = np.linalg.svd(G, full_matrices=False)
        self.U_B, self.S_B, self.Vt_B = np.linalg.svd(B, full_matrices=False)
        
        self.max_rank = min(len(self.S_R), len(self.S_G), len(self.S_B))
    
    def reconstruct_channel(self, U, S, Vt, k):
        """重建單一通道"""
        U_k = U[:, :k]
        S_k = S[:k]
        Vt_k = Vt[:k, :]
        return np.dot(U_k, np.dot(np.diag(S_k), Vt_k))
    
    def reconstruct_image(self, k):
        """重建 RGB 圖片"""
        k = min(k, self.max_rank)
        k = max(1, k)
        
        R_approx = self.reconstruct_channel(self.U_R, self.S_R, self.Vt_R, k)
        G_approx = self.reconstruct_channel(self.U_G, self.S_G, self.Vt_G, k)
        B_approx = self.reconstruct_channel(self.U_B, self.S_B, self.Vt_B, k)
        
        img_approx = np.stack([R_approx, G_approx, B_approx], axis=2)
        return np.clip(img_approx, 0, 255).astype(np.uint8)
    
    def calculate_psnr(self, original, compressed):
        """計算 PSNR"""
        mse = np.mean((original.astype(float) - compressed.astype(float)) ** 2)
        if mse == 0:
            return float('inf')
        max_val = 255.0
        psnr = 10 * np.log10((max_val ** 2) / mse)
        return psnr
    
    def display_image(self, label, img_array):
        """在 QLabel 上顯示圖片"""
        height, width = img_array.shape[:2]
        bytes_per_line = 3 * width
        
        q_image = QImage(img_array.data, width, height, bytes_per_line, QImage.Format_RGB888)
        pixmap = QPixmap.fromImage(q_image)
        
        # 縮放以適應 label
        scaled_pixmap = pixmap.scaled(
            label.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation
        )
        label.setPixmap(scaled_pixmap)
    
    # ==================== 滑桿控制 ====================
    
    def ratio_slider_changed(self, value):
        """壓縮比例滑桿改變"""
        self.ratio_value_label.setText(f"{value}%")
        
        # 更新目標大小滑桿
        target_size = self.original_size_mb * (value / 100)
        self.size_slider.blockSignals(True)
        self.size_slider.setValue(int(target_size * 100))
        self.size_value_label.setText(f"{target_size:.2f} MB")
        self.size_slider.blockSignals(False)
        
        # 更新壓縮
        self.update_compression()
    
    def size_slider_changed(self, value):
        """目標大小滑桿改變"""
        target_size = value / 100
        self.size_value_label.setText(f"{target_size:.2f} MB")
        
        # 更新壓縮比例滑桿
        if self.original_size_mb > 0:
            ratio = (target_size / self.original_size_mb) * 100
            ratio = min(100, max(1, ratio))
            self.ratio_slider.blockSignals(True)
            self.ratio_slider.setValue(int(ratio))
            self.ratio_value_label.setText(f"{int(ratio)}%")
            self.ratio_slider.blockSignals(False)
        
        # 更新壓縮
        self.update_compression()
    
    def update_compression(self):
        """更新壓縮預覽"""
        if self.original_image is None:
            return
        
        # 根據比例計算 k
        ratio = self.ratio_slider.value() / 100
        k = int(self.max_rank * ratio)
        k = max(1, min(k, self.max_rank))
        
        # 重建圖片
        self.compressed_image = self.reconstruct_image(k)
        
        # 計算 PSNR
        psnr = self.calculate_psnr(self.original_image, self.compressed_image)
        
        # 更新顯示
        self.display_image(self.compressed_image_label, self.compressed_image)
        
        # 更新資訊
        compressed_size = len(self.compressed_image.tobytes()) / (1024 * 1024)
        self.compressed_ratio_label.setText(f"{int(ratio * 100)}%")
        self.compressed_size_label.setText(f"{compressed_size:.2f} MB")
        self.compressed_psnr_label.setText(f"{psnr:.2f} dB")
        
        # PSNR 警告
        if psnr < 40:
            self.compressed_psnr_label.setStyleSheet("color: red; font-weight: bold;")
            QMessageBox.warning(
                self, "品質警告", 
                f"目前 PSNR 為 {psnr:.2f} dB，低於建議值 40 dB！\n建議提高壓縮比例以保持品質。"
            )
        else:
            self.compressed_psnr_label.setStyleSheet("color: green; font-weight: bold;")
    
    # ==================== 預設模板 ====================
    
    def apply_template(self, index):
        """套用預設模板"""
        if self.original_image is None:
            return
        
        if index == 1:  # 社群媒體
            target_size = min(2, self.original_size_mb)
            ratio = (target_size / self.original_size_mb) * 100
            self.ratio_slider.setValue(int(ratio))
        elif index == 2:  # 郵件附件
            target_size = min(5, self.original_size_mb)
            ratio = (target_size / self.original_size_mb) * 100
            self.ratio_slider.setValue(int(ratio))
        elif index == 3:  # 高品質
            self.ratio_slider.setValue(80)
    
    def apply_suggestion(self, suggestion_num):
        """套用建議"""
        if self.original_image is None:
            QMessageBox.warning(self, "提醒", "請先上傳圖片！")
            return
        
        if suggestion_num == 1:
            # 社群媒體優化
            target_size = min(2, self.original_size_mb)
            ratio = (target_size / self.original_size_mb) * 100
            self.ratio_slider.setValue(int(ratio))
        elif suggestion_num == 2:
            # 平衡模式
            self.ratio_slider.setValue(50)
        elif suggestion_num == 3:
            # 高品質
            self.ratio_slider.setValue(80)
    
    # ==================== 儲存功能 ====================
    
    def save_compressed_image(self):
        """儲存壓縮後的圖片"""
        if self.compressed_image is None:
            QMessageBox.warning(self, "提醒", "尚未進行壓縮！")
            return
        
        file_name, _ = QFileDialog.getSaveFileName(
            self, "儲存壓縮圖片", "", "PNG 檔案 (*.png);;JPEG 檔案 (*.jpg)"
        )
        
        if file_name:
            try:
                img = Image.fromarray(self.compressed_image)
                img.save(file_name)
                QMessageBox.information(self, "成功", "圖片已儲存！")
            except Exception as e:
                QMessageBox.critical(self, "錯誤", f"儲存失敗：{str(e)}")


# 主程式
if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = SVDCompressionApp()
    window.show()
    sys.exit(app.exec_())

