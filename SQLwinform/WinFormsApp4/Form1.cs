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
               	string localDbConn = @"Server=172.31.10.251\sql2012;Database=wsbase660;User Id=sa;Password=system;";
                //string localDbConn = "Server=172.31.10.251\\sql2012;Database=wsbase660;User Id=sa;Password=system;";
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
