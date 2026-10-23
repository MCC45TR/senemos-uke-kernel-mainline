/* SPDX-License-Identifier: GPL-2.0-only */
#include <assert.h>
#include <errno.h>
struct spi_message { int status; };
struct spi_controller { struct spi_message *cur_msg; int dev; };
struct dmaengine_result { int result; unsigned int residue; };
#define DMA_TRANS_NOERROR 0
#define dev_err(dev, ...) ((void)(dev))
#define dev_dbg(dev, ...) ((void)(dev))
static unsigned int completed;
static void spi_finalize_current_transfer(struct spi_controller *spi)
{
	(void)spi;
	completed++;
}
#include "production.h"
int main(void)
{
	struct spi_message message = { .status = -EINPROGRESS };
	struct spi_controller controller = { .cur_msg = &message };
	struct dmaengine_result result = { 0 };

	spi_gsi_callback_result(&controller, &result);
	assert(completed == 1 && message.status == -EINPROGRESS);
	result.residue = 1;
	spi_gsi_callback_result(&controller, &result);
	assert(completed == 2 && message.status == -EIO);
	message.status = -EINPROGRESS;
	result.residue = 0;
	result.result = 1;
	spi_gsi_callback_result(&controller, &result);
	assert(completed == 3 && message.status == -EIO);
	return 0;
}
