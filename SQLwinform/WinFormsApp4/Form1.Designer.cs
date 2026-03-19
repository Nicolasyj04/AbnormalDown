/*
 * Created by SharpDevelop.
 * User: USER
 * Date: 2026-03-13
 * Time: 11:50
 * 
 * To change this template use Tools | Options | Coding | Edit Standard Headers.
 */

namespace WinFormsApp4
{
    partial class Form1
    {
        /// <summary>
        ///  Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        ///  Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        private System.Windows.Forms.DateTimePicker dtpFetchTime;
        private System.Windows.Forms.TextBox txtSysNo;
        private System.Windows.Forms.Button btnAnalyze;
        #region Windows Form Designer generated code

        /// <summary>
        ///  Required method for Designer support - do not modify
        ///  the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.dtpFetchTime = new System.Windows.Forms.DateTimePicker();
            this.txtSysNo = new System.Windows.Forms.TextBox();
            this.btnAnalyze = new System.Windows.Forms.Button();
            this.SuspendLayout();
            // 
            // dtpFetchTime
            // 
            this.dtpFetchTime.Location = new System.Drawing.Point(30, 30);
            this.dtpFetchTime.Name = "dtpFetchTime";
            this.dtpFetchTime.Size = new System.Drawing.Size(200, 23);
            // 
            // txtSysNo
            // 
            this.txtSysNo.Location = new System.Drawing.Point(30, 70);
            this.txtSysNo.Name = "txtSysNo";
            this.txtSysNo.Size = new System.Drawing.Size(200, 23);
            //this.txtSysNo.PlaceholderText = "系统编号";
            // 
            // btnAnalyze
            // 
            this.btnAnalyze.Location = new System.Drawing.Point(30, 110);
            this.btnAnalyze.Name = "btnAnalyze";
            this.btnAnalyze.Size = new System.Drawing.Size(200, 30);
            this.btnAnalyze.Text = "执行分析";
            this.btnAnalyze.UseVisualStyleBackColor = true;
            this.btnAnalyze.Click += new System.EventHandler(this.btnAnalyze_Click);
            // 
            // Form1
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(7F, 15F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(300, 180);
            this.Controls.Add(this.dtpFetchTime);
            this.Controls.Add(this.txtSysNo);
            this.Controls.Add(this.btnAnalyze);
            this.Name = "Form1";
            this.Text = "产线分析测试";
            this.ResumeLayout(false);
            this.PerformLayout();
        }

        #endregion
    }
}
