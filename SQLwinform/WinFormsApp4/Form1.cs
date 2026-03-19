/*
 * Created by SharpDevelop.
 * User: USER
 * Date: 2026-03-13
 * Time: 11:50
 * 
 * To change this template use Tools | Options | Coding | Edit Standard Headers.
 */

using System;
using System.Windows.Forms;

namespace WinFormsApp4
{
    public partial class Form1 : Form
    {
        public Form1()
        {
            InitializeComponent();
        }

        private void btnAnalyze_Click(object sender, EventArgs e)
        {
            try
            {
                DateTime fetchTime = dtpFetchTime.Value;
                string sysNo = txtSysNo.Text;
                string localDbConn = "Server=myServer;Database=myDB;User Id=myUser;Password=myPassword;"; // 请替换为你的实际连接字符串

                ProductLineAnalyzer analyzer = new ProductLineAnalyzer(localDbConn);
                analyzer.ExecuteAnalysis(fetchTime, sysNo);
                MessageBox.Show("分析并写入完成！", "成功", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show(string.Format("发生错误: {0}", ex.Message), "错误", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }
}
